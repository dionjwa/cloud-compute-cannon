package ccc.compute.server.execution.routes;

import ccc.compute.worker.QueueJobs;
import ccc.storage.ServiceStorage;
import ccc.compute.server.services.queue.QueueTools;
import ccc.compute.worker.BatchComputeDocker;
import ccc.compute.worker.BatchComputeDockerTurbo;

import haxe.Json;
import haxe.remoting.JsonRpc;
import haxe.extern.EitherType;

import js.node.http.*;
import js.node.Http;
import js.node.stream.Readable;
import js.Node;
import js.npm.bull.Bull;
import js.npm.busboy.Busboy;
import js.npm.docker.Docker;
import js.npm.redis.RedisClient;
import js.npm.ssh2.Ssh;
import js.npm.streamifier.Streamifier;
import js.npm.streamifier.Streamifier;

import minject.Injector;

import promhx.Promise;

import t9.js.jsonrpc.Routes;

import util.DockerRegistryTools;
import util.DockerTools;
import util.DockerUrl;
import util.RedisTools;
import util.streams.StdStreams;

class ServiceBatchComputeTools
{
	static var DEFAULT_JOB_PARAMS :JobParams = {cpus:1, maxDuration:600};//10 minutes

	public static function runTurboJobRequestV2(injector :Injector, job :BatchProcessRequestTurboV2) :Promise<JobResultsTurboV2>
	{
		if (job == null) {
			throw 'Null job argument in ServiceBatchCompute.run(...)';
		}

		job.id = getOrEnsureId(job.id);

		var promise = new DeferredPromise<JobResultsTurboV2>();

		var bullQueues = injector.getValue(Queues);
		Assert.notNull(bullQueues);

		job.parameters = ensureGoodJobParameters(job.parameters);

		var bullQueue :Queue<QueueJobDefinition, ccc.compute.worker.QueueJobResults> = bullQueues.getQueue(job.parameters);
		Assert.notNull(bullQueue);

		var jobCompletedHandler;
		var jobFailedHandler;
		var timeoutId;

		function cleanup() {
			if (promise != null) {
				bullQueue.removeListener('global:${QueueEvent.Completed}', jobCompletedHandler);
				bullQueue.removeListener('global:${QueueEvent.Failed}', jobFailedHandler);

				promise = null;
			}
			if (timeoutId != null) {
				Node.clearTimeout(timeoutId);
				timeoutId = null;
			}
		}
		timeoutId = Node.setTimeout(function() {
			if (promise != null) {
				Log.info(LogFieldUtil.addJobEvent({jobId:job.id, type:QueueJobDefinitionType.turbo, message: 'TIMEOUT', JOB_TURBO_MAX_TIME_SECONDS:ServerConfig.JOB_TURBO_MAX_TIME_SECONDS}, JobEventType.ERROR));
				promise.boundPromise.reject('Timeout');
			}
			cleanup();
		}, ServerConfig.JOB_TURBO_MAX_TIME_SECONDS * 1000);

		//Set up listeners
		jobCompletedHandler = function(completedJob, resultString :String) {
			var result :JobResultsTurboV2 = Json.parse(resultString);
			if (completedJob == job.id) {
				Log.debug({jobId:job.id, message:'SUCCESS TURBO JOB', result:result});

				//Maybe convert outputs to UTF8 text
				if (result.outputs != null && job.forceUtf8Outputs) {
					for (i in 0...result.outputs.length) {
						var output = result.outputs[i];
						if (!(output.encoding == null || output.encoding == 'utf8')) {
							output.value = Buffer.from(output.value, output.encoding).toString('utf8');
							output.encoding = 'utf8';
						}
					}
				}

				if (promise != null) {
					promise.resolve(result);
				}
				cleanup();
			}
		}
		jobFailedHandler = function(failedJob, err) {
			if (failedJob == job.id) {
				Log.warn({jobId:job.id, message:'FAILED TURBO JOB', error:err});
				if (promise != null) {
					promise.boundPromise.reject(err);
				}
				cleanup();
			}
		}
		bullQueue.on('global:${QueueEvent.Completed}', jobCompletedHandler);
		bullQueue.on('global:${QueueEvent.Failed}', jobFailedHandler);

		//Add job to the queue
		var job :QueueJobDefinition = {
			id: job.id,
			type: QueueJobDefinitionType.turbo,
			item: job,
			priority: false,
			parameters: null,
			attempt: 1
		}

		return QueueTools.addJobToQueue(bullQueue, job)
			.pipe(function(_) {
				return promise.boundPromise;
			});
	}

	public static function runComputeJobRequest(injector :Injector, job :BasicBatchProcessRequest) :Promise<JobResult>
	{
		if (job == null) {
			throw 'Null job argument in ServiceBatchCompute.run(...)';
		}

		job.image = job.image == null ? Constants.DOCKER_IMAGE_DEFAULT : job.image;
		job.id = getOrEnsureId(job.id);
		var jobId :JobId = job.id;
		JobStatsTools.requestRecieved(jobId, Date.now().getTime());

		var fs :ServiceStorage = injector.getValue(ServiceStorage);
		var redis :RedisClient = injector.getValue(RedisClient);

		var deleteInputs :Void->Promise<Bool> = null;
		var error :Dynamic = null;

		return Promise.promise(true)
			.pipe(function(_) {
				var dateString = Date.now().format("%Y-%m-%d");
				var inputs = null;
				var inputPath = job.inputsPath != null ? (job.inputsPath.endsWith('/') ? job.inputsPath : job.inputsPath + '/') : jobId.defaultInputDir();

				var parameters :JobParams = ensureGoodJobParameters(job.parameters);
				var inputFilesObj = writeInputFiles(fs, job.inputs, inputPath);
				deleteInputs = inputFilesObj.cancel;
				var dockerImage :String = job.image == null ? DOCKER_IMAGE_DEFAULT : job.image;
				var dockerJob :DockerBatchComputeJob = {
					id: jobId,
					image: {type:DockerImageSourceType.Image, value:dockerImage, pull_options:job.pull_options, optionsCreate:job.createOptions},
					command: job.cmd,
					inputs: inputFilesObj.inputs,
					workingDir: job.workingDir,
					inputsPath: job.inputsPath,
					outputsPath: job.outputsPath,
					resultsPath: job.resultsPath,
					containerInputsMountPath: job.containerInputsMountPath,
					containerOutputsMountPath: job.containerOutputsMountPath,
					parameters: parameters,
					meta: job.meta,
					appendStdOut: job.appendStdOut,
					appendStdErr: job.appendStdErr,
					mountApiServer: job.mountApiServer,
				};

				var dockerJobLog :DockerBatchComputeJob = Json.parse(Json.stringify(dockerJob));
				if (dockerJobLog.image != null && dockerJobLog.image.pull_options != null) {
					dockerJobLog.image.pull_options.authconfig = null;
				}

				Log.info({job_submission :dockerJob.id}.add(LogEventType.JobSubmitted));
				Log.debug({job_submission :dockerJobLog});

				if (dockerJob.command != null && untyped __typeof__(dockerJob.command) == 'string') {
					throw 'command field must be an array, not a string';
				}
#if debug
				//Check the results path since we're not using UUID's anymore
				var resultsJsonPath = JobTools.resultJsonPath(dockerJob);
				return fs.exists(resultsJsonPath)
					.then(function(exists) {
						if (exists) {
							throw 'jobId=$jobId results.json already exists at $resultsJsonPath';
						}
						return true;
					})
#else
				return Promise.promise(true)
#end
					.pipe(function(_) {
						return inputFilesObj.promise;
					})
					.pipe(function(result) {
						var job :QueueJobDefinition = {
							id: jobId,
							type: QueueJobDefinitionType.compute,
							item: dockerJob,
							parameters: parameters,
							priority: job.priority,
							attempt: 1
						}
						return QueueTools.addJob(injector, job);
					})
					.thenTrue();
			})
			//It has this odd errorPipe (then maybe throw later) promise
			//structure because otherwise the caught and rethrown error
			//won't actually be passed down the promise chain
			.errorPipe(function(err) {
				Log.error('Got error, deleting inputs for jobId=$jobId err=$err');
				error = err;
				if (deleteInputs != null) {
					var deletePromise = deleteInputs();
					if (deletePromise != null) {
						deletePromise.then(function(_) {
							Log.error('Deleted inputs for jobId=$jobId err=$err');
						});
					}
				}
				return Promise.promise(true);
			})
			.pipe(function(_) {
				if (error != null) {
					JobStateTools.setFinishedStatus(jobId, JobFinishedStatus.Failed, Json.stringify({error:error, message: 'Failed during submission, job results possibly not present.'}));
					// JobStatsTools.jobFinished(jobId, Json.stringify(error));
					throw error;
				}
				if (job.wait == true) {
					// return getJobResult(jobId, job.parameters != null && job.parameters.maxDuration != null ? job.parameters.maxDuration : null);
					return JobCommands.getJobResult(injector, jobId);
				} else {
					var jobResult :JobResult = {jobId:jobId};
					return Promise.promise(jobResult);
				}
			});
	}

	public static function handleMultiformBatchComputeRequest(injector :Injector, req :js.node.http.IncomingMessage, res :js.node.http.ServerResponse, next :?Dynamic->Void) :Void
	{
        var timeRequestReceived = Date.now().getTime();
		var fs :ServiceStorage = injector.getValue(ServiceStorage);
		var redis :RedisClient = injector.getValue(RedisClient);

		var returned = false;
		var jsonrpc :RequestDefTyped<BasicBatchProcessRequest> = null;
		var promises = [];
		var jobId :JobId = null;
		var inputPath = null;
		var inputFileNames :Array<String> = [];

		var log = Log.log;

		function returnError(err :haxe.extern.EitherType<String, js.Error>, ?statusCode :Int = 500) {
			log.error({error:err, jsonrpc:jsonrpc, message: 'Failed handleMultiformBatchComputeRequest'}.add(LogEventType.JobError));
			if (returned) return;
			res.writeHead(statusCode, {'content-type': 'application/json'});
			res.end(Json.stringify({error: err}));
			returned = true;
			//Cleanup
			Promise.whenAll(promises)
				.then(function(_) {
					if (jsonrpc != null && jsonrpc.params != null && jsonrpc.params.inputsPath != null) {
						fs.deleteDir(jsonrpc.params.inputsPath)
							.then(function(_) {
								log.debug({message:'Got error, deleted job ${jsonrpc.params.inputsPath}'}.add(LogEventType.JobError));
							})
							.catchError(function(err) {
								log.debug({error:err, message:'deleting inputs after previous error'}.add(LogEventType.JobError));
							});
					} else {
						if (jobId != null) {
							fs.deleteDir(jobId)
								.then(function(_) {
									log.debug({message:'Deleted job dir err=$err'}.add(LogEventType.JobError));
								})
								.catchError(function(err) {
									log.debug({error:err, message:'deleting inputs after previous error'}.add(LogEventType.JobError));
								});
						}
					}
				});
		}

		function parseJsonRpc(val :String) {
			var fieldName = JsonRpcConstants.MULTIPART_JSONRPC_KEY;
			try {
				try {
					jsonrpc = Json.parse(val);
				} catch (err :Dynamic) {
					//Try URL-decoding
					val = StringTools.urlDecode(val);
					jsonrpc = Json.parse(val);
				}
				if (jsonrpc.method == null || jsonrpc.method != Constants.RPC_METHOD_JOB_SUBMIT) {
					returnError('JsonRpc method ${Constants.RPC_METHOD_JOB_SUBMIT} != ${jsonrpc.method}');
					return;
				}
				if (jsonrpc.method == null || jsonrpc.method != Constants.RPC_METHOD_JOB_SUBMIT) {
					returnError('JsonRpc method ${Constants.RPC_METHOD_JOB_SUBMIT} != ${jsonrpc.method}');
					return;
				}

				jsonrpc.params.id = getOrEnsureId(jsonrpc.params.id);
				jobId = jsonrpc.params.id;
				JobStatsTools.requestRecieved(jobId, timeRequestReceived);

				inputPath = jsonrpc.params.inputsPath != null ? (jsonrpc.params.inputsPath.endsWith('/') ? jsonrpc.params.inputsPath : jsonrpc.params.inputsPath + '/') : jobId.defaultInputDir();
				if (jsonrpc.params.inputs != null) {
					var inputFilesObj = writeInputFiles(fs, jsonrpc.params.inputs, inputPath);
					promises.push(inputFilesObj.promise.thenTrue());
					inputFilesObj.inputs.iter(inputFileNames.push);
				}
			} catch(err :Dynamic) {
				log.error(err);
				returnError('Failed to parse JSON, err=$err val=$val');
			}
		}

		log = log.child({jobId:jobId});
		log.debug({message: 'Starting busboy compute request'});
		var tenGBInBytes = 10737418240;
		var busboy = new Busboy({headers:req.headers, limits:{fieldNameSize:500, fieldSize:tenGBInBytes}});
		var deferredFieldHandling = [];//If the fields come in out of order, we'll have to handle the non-JSON-RPC subsequently
		busboy.on(BusboyEvent.File, function(fieldName, stream, fileName, encoding, mimetype) {

			if (fieldName == JsonRpcConstants.MULTIPART_JSONRPC_KEY) {
				StreamPromises.streamToString(stream)
					.then(function(jsonrpcString) {
						parseJsonRpc(jsonrpcString);
					});
			} else {
				// if (inputPath == null) {
				// 	returnError('fieldName=$fieldName fileName=$fileName inputPath is null for a file input, meaning either there is no jsonrpc entry, or it has not finished loading, or the jsonrpc file is after this. The \'jsonrpc\' key must be first in the multipart request.', 400);
				// 	return;
				// }
				var attemptsMax = 8;
				var attempts = 0;
				function attempLoad() {
					if (inputPath == null) {
						attempts++;
						return false;
					}

					log.debug('BusboyEvent.File writing input file $fieldName encoding=$encoding mimetype=$mimetype stream=${stream != null}');
					var inputFilePath = inputPath + fieldName;

					stream.on(ReadableEvent.Error, function(err) {
						log.error({error:err, message:'Error in Busboy reading field=$fieldName fileName=$fileName mimetype=$mimetype'}.add(LogEventType.JobError));
					});
					stream.on('limit', function() {
						log.error({message:'Limit event in Busboy reading field=$fieldName fileName=$fileName mimetype=$mimetype'}.add(LogEventType.JobError));
					});

					var fileWritePromise = fs.writeFile(inputFilePath, stream);
					fileWritePromise
						.then(function(_) {
							log.debug('finished writing input file $fieldName');
							return true;
						})
						.errorThen(function(err) {
							log.debug('error writing input file $fieldName err=$err');
							throw err;
							return true;
						});
					promises.push(fileWritePromise);
					inputFileNames.push(fieldName);
					return true;
				}

				var delay :Void->Void = null;
				delay = function() {
					attempts++;
					if (returned) {
						return;
					}
					if (attempts > attemptsMax) {
						returnError('fieldName=$fieldName fileName=$fileName inputPath is null for a file input, meaning either there is no jsonrpc entry, or it has not finished loading, or the jsonrpc file is after this. The \'jsonrpc\' key must be first in the multipart request.', 400);
					} else {
						Node.setTimeout(function() {
							if (!attempLoad()) {
								delay();
							}
						}, 100);
					}
				}

				if (!attempLoad()) {
					delay();
				}
			}
		});
		busboy.on(BusboyEvent.Field, function(fieldName, val, fieldnameTruncated, valTruncated) {
			if (returned) {
				return;
			}
			if (fieldName == JsonRpcConstants.MULTIPART_JSONRPC_KEY) {
				parseJsonRpc(val);
			} else {
				if (jsonrpc == null) {
					returnError('The "jsonrpc" multipart key must be the FIRST entry in the multipart request form', 404);
					return;
				}
				var inputFilePath = (jsonrpc.params.inputsPath != null ? (jsonrpc.params.inputsPath.endsWith('/') ? jsonrpc.params.inputsPath : jsonrpc.params.inputsPath + '/') : jobId.defaultInputDir()) + fieldName;
				var fileWritePromise = fs.writeFile(inputFilePath, Streamifier.createReadStream(val));
				fileWritePromise
					.then(function(_) {
						log.debug('finished writing input file $fieldName');
						return true;
					})
					.errorThen(function(err) {
						log.error({error:err, message:'error writing input file $fieldName'}.add(LogEventType.JobError));
						throw err;
						return true;
					});
				promises.push(fileWritePromise);
				inputFileNames.push(fieldName);
			}
		});

		busboy.on(BusboyEvent.Finish, function() {
			if (returned) {
				return;
			}
			Promise.promise(true)
				.pipe(function(_) {
					return Promise.whenAll(promises);
				})
				.pipe(function(_) {
					JobStatsTools.requestUploaded(jobId);

					var parameters :JobParams = ensureGoodJobParameters(jsonrpc.params.parameters);
					var dockerImage :String = jsonrpc.params.image == null ? DOCKER_IMAGE_DEFAULT : jsonrpc.params.image;
					var dockerJob :DockerBatchComputeJob = {
						id: jobId,
						image: {type:DockerImageSourceType.Image, value:dockerImage, pull_options:jsonrpc.params.pull_options, optionsCreate:jsonrpc.params.createOptions},
						command: jsonrpc.params.cmd,
						inputs: inputFileNames,
						workingDir: jsonrpc.params.workingDir,
						inputsPath: jsonrpc.params.inputsPath,
						outputsPath: jsonrpc.params.outputsPath,
						containerInputsMountPath: jsonrpc.params.containerInputsMountPath,
						containerOutputsMountPath: jsonrpc.params.containerOutputsMountPath,
						resultsPath: jsonrpc.params.resultsPath,
						parameters: parameters,
						meta: jsonrpc.params.meta,
						appendStdOut: jsonrpc.params.appendStdOut,
						appendStdErr: jsonrpc.params.appendStdErr,
						mountApiServer: jsonrpc.params.mountApiServer,
					};

					log.debug({job_submission :dockerJob});

					if (jsonrpc.params.cmd != null && untyped __typeof__(jsonrpc.params.cmd) == 'string') {
						throw 'command field must be an array, not a string';
					}

					var job :QueueJobDefinition = {
						id: jobId,
						type: QueueJobDefinitionType.compute,
						item: dockerJob,
						parameters: parameters,
						priority: jsonrpc.params.priority == true,
						attempt: 1
					}
					return Promise.promise(true)
						.pipe(function(_) {
							return QueueTools.addJob(injector, job, log);
						});
				})
				.then(function(_) {
					var maxDuration = jsonrpc.params.parameters != null && jsonrpc.params.parameters.maxDuration != null ? jsonrpc.params.parameters.maxDuration : null;
					JobCommands.returnJobResult(injector, res, jobId, jsonrpc.id, jsonrpc.params.wait, maxDuration);
				})
				.catchError(function(err) {
					JobStateTools.setFinishedStatus(jobId, JobFinishedStatus.Failed, Json.stringify({error:error, message: 'Failed during submission, job results possibly not present.'}));
					log.error({error:err, message:'error in job submission'}.add(LogEventType.JobError));
					returnError(err);
				});
		});
		busboy.on(BusboyEvent.PartsLimit, function() {
			log.error({message:'BusboyEvent ${BusboyEvent.PartsLimit}'}.add(LogEventType.JobError));
		});
		busboy.on(BusboyEvent.FilesLimit, function() {
			log.error({message:'BusboyEvent ${BusboyEvent.FilesLimit}'}.add(LogEventType.JobError));
		});
		busboy.on(BusboyEvent.FieldsLimit, function() {
			log.error({message:'BusboyEvent ${BusboyEvent.FieldsLimit}'}.add(LogEventType.JobError));
		});
		busboy.on('error', function(err) {
			log.error({error:err, message:'BusboyEvent error'}.add(LogEventType.JobError));
			returnError(err);
		});
		req.pipe(busboy);
	}

	static function getNewJobId() :JobId
	{
		return JobTools.generateJobId();
	}

	/**
	 * Write inputs to the StorageService.
	 * @param  inputs     :Array<DataSource> [description]
	 * @param  inputsPath :String                    Path prefix to the input file.
	 * @return            A function that will cancel (delete) the written files if an error is triggered later.
	 */
	public static function writeInputFiles(fs :ServiceStorage, inputDescriptions :Array<DataBlob>, inputsPath :String) :{cancel:Void->Promise<Bool>, inputs:Array<String>, promise:Promise<Dynamic>}
	{
		var promises = [];
		var inputNames = [];
		if (inputDescriptions != null) {
			for (input in inputDescriptions) {
				var inputFilePath = Path.join(inputsPath, input.name);
				var source :DataSource = input.source == null ? DataSource.InputInline : input.source;
				var encoding :DataEncoding = input.encoding == null ? DataEncoding.utf8 : input.encoding;
				switch(encoding) {
					case utf8,base64,ascii,utf16le,ucs2,binary,hex:
					default: throw 'Unsupported input encoding=$encoding';
				}
				switch(source) {
					case InputInline:
						if (input.value != null) {
							var buffer = new Buffer(Std.string(input.value), encoding);
							promises.push(fs.writeFile(inputFilePath, Streamifier.createReadStream(buffer)));//{encoding:encoding}
							inputNames.push(input.name);
						}
					case InputUrl:
						if (input.value == null) {
							throw 'input.value is null for $input';
						}
						var url :String = input.value;
						if (url.startsWith('http')) {
							var request :String->IReadable = Node.require('request');
							//Fuck the request library
							//https://github.com/request/request/issues/887
							var readable :js.node.stream.Duplex<Dynamic> = untyped __js__('new require("stream").PassThrough()');
							request(input.value).pipe(readable);
							promises.push(fs.writeFile(inputFilePath, readable));
						} else {
							Log.warn({url:url});
							promises.push(
								fs.readFile(url)
									.pipe(function(stream) {
										return fs.writeFile(inputFilePath, stream);
									}));
						}
						inputNames.push(input.name);
					default:
						throw 'Unhandled input type="$source" from $inputDescriptions';
				}
			}
		}
		return {promise:Promise.whenAll(promises), inputs:inputNames, cancel:function() return fs.deleteDir(inputsPath)};
	}

	public static function ensureGoodJobParameters(?params :JobParams) :JobParams
	{
		if (params == null) {
			params = Reflect.copy(DEFAULT_JOB_PARAMS);
		}
		if (params.cpus == null && params.gpu == null) {
			params.cpus = 1;
		}

		//GPU implicity requires a CPU and GPU workers have their VCPU count
		//reduced accordingly
		if (params.gpu > 0) {
			params.cpus = 0;
		}
		return params;
	}

	static function getOrEnsureId(id :JobId) :JobId
	{
		return id == null || id == "" ? getNewJobId() : id;
	}
}
