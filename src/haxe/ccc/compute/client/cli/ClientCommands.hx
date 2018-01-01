package ccc.compute.client.cli;

import ccc.compute.client.js.ClientJSTools;
import ccc.compute.client.cli.CliTools.*;
import ccc.compute.client.util.ClientCompute;

import haxe.Resource;

import js.node.http.*;
import js.node.ChildProcess;
import js.node.Path;
import js.node.stream.Readable;
import js.node.Fs;
import js.npm.fsextended.FsExtended;
import js.npm.request.Request;

import yaml.Yaml;

import util.SshTools;
import util.streams.StreamTools;

using ccc.compute.server.execution.ComputeTools;
using t9.util.ColorTraces;

enum ClientResult {
	Websocket;
}

typedef ClientJobRecord = {
	var jobId :JobId;
	var jobRequest :BasicBatchProcessRequest;
}

typedef JobWaitingStatus = {
	var jobId :JobId;
	var status :String;
	@:optional var error :Dynamic;
	@:optional var job : JobDataBlob;
}

@:enum
abstract DevTestCommand(String) to String from String {
	var longjob = 'longjob';
	var shellcommand = 'shellcommand';
}

typedef SubmissionDataBlob = {
	var jobId :JobId;
}

/**
 * "Remote" methods that run locally
 */
class ClientCommands
{
	// @rpc({
	// 	alias:'version',
	// 	doc:'Client and server version'
	// })
	// public static function versionCheck() :Promise<CLIResult>
	// {
	// 	return getVersions()
	// 		.then(function(versionBlob) {
	// 			trace(Json.stringify(versionBlob, null, '\t'));
	// 			if (versionBlob.server != null && versionBlob.server.npm != versionBlob.client.npm) {
	// 				warn('Version mismatch');
	// 				return CLIResult.ExitCode(1);
	// 			} else {
	// 				return CLIResult.Success;
	// 			}
	// 		});
	// }

	// @rpc({
	// 	alias:'run',
	// 	doc:'Run docker job(s) on the compute provider.',
	// 	args:{
	// 		command: {doc:'Command to run in the docker container, specified as 1) a single word such as the script path 2) a single quoted string, which will be split (via spaces) into words (e.g. "echo foo") 3) a single string of a JSON array, e.g. \'[\"echo\",\"boo\"]\'. Space delimited commands are problematic to parse correctly.', short:'c'},
	// 		directory: {doc: 'Path to directory containing the job definition', short:'d'},
	// 		image: {doc: 'Docker image name [docker.io/busybox:latest]', short: 'm'},
	// 		input: {doc:'Input values (decoded into JSON values) [input]. E.g.: --input foo1=SomeString --input foo2=2 --input foo3="[1,2,3,4]". ', short:'i'},
	// 		inputfile: {doc:'Input files [inputfile]. E.g. --inputfile foo1=/home/user1/Desktop/test.jpg" --input foo2=/home/me/myserver/myfile.txt ', short:'f'},
	// 		inputurl: {doc:'Input urls (downloaded from the server) [inputurl]. E.g. --input foo1=http://someserver/test.jpg --input foo2=http://myserver/myfile', short:'u'},
	// 		results: {doc: 'Results directory [./<results_dir>/<date string>__<jobId>/]. The contents of that folder will have an inputs/ and outputs/ directories. ', short:'r'},
	// 		wait: {doc: 'Wait until the job is finished before returning (default is to return the jobId immediately, then query using that jobId, since jobs may take a long time)', short:'w'},
	// 	},
	// 	docCustom: 'Example:\n cloudcannon run --image=elyase/staticpython --command=\'["python", "-c", "print(\\\"Hello World!\\\")"]\''
	// })
	// public static function runclient(
	// 	?command :String,
	// 	?image :String,
	// 	?directory :String,
	// 	?input :Array<String>,
	// 	?inputfile :Array<String>,
	// 	?inputurl :Array<String>,
	// 	?results :String,
	// 	?wait :Bool = false
	// 	)
	// {
	// 	var commandArray :Array<String> = null;
	// 	if (command != null) {
	// 		if (command.startsWith('[')) {
	// 			try {
	// 				commandArray = Json.parse(command);
	// 			} catch(ignoredError :Dynamic) {}
	// 		} else {
	// 			commandArray = command.split(' ').filter(function(s) return s.length > 0).array();
	// 		}
	// 	}
	// 	var jobParams :BasicBatchProcessRequest = {
	// 		image: image != null ? image : Constants.DOCKER_IMAGE_DEFAULT,
	// 		cmd: commandArray,
	// 		parameters: {cpus:1, maxDuration:60*1000*10},
	// 		inputs: [],
	// 		wait: wait
	// 	};
	// 	return runCli(jobParams, input, inputfile, inputurl, results);
	// }

	// @rpc({
	// 	alias:'runjson',
	// 	doc:'Run docker job(s) on the compute provider.',
	// 	args:{
	// 		jsonfile: {doc: 'Path to json file with the job spec'},
	// 		input: {doc:'Input files/values/urls [input]. Formats: --input "foo1=@/home/user1/Desktop/test.jpg" --input "foo2=@http://myserver/myfile --input "foo3=4". ', short:'i'},
	// 		inputfile: {doc:'Input files/values/urls [input]. Formats: --input "foo1=@/home/user1/Desktop/test.jpg" --input "foo2=@http://myserver/myfile --input "foo3=4". ', short:'i'},
	// 		results: {doc: 'Results directory [./<results_dir>/<date string>__<jobId>/]. The contents of that folder will have an inputs/ and outputs/ directories. '},
	// 	},
	// 	docCustom: 'Example:\n cloudcannon run --image=elyase/staticpython --command=\'["python", "-c", "print(\\\\\\\"Hello Worlds!\\\\\\\")"]\''
	// })
	// public static function runJson(
	// 	jsonfile: String,
	// 	?input :Array<String>,
	// 	?inputfile :Array<String>,
	// 	?inputurl :Array<String>,
	// 	?results: String,
	// 	?wait: Bool = false
	// 	)
	// {
	// 	var jobParams :BasicBatchProcessRequest = Json.parse(Fs.readFileSync(jsonfile, 'utf8'));
	// 	if (jobParams.wait == null) {
	// 		jobParams.wait = wait;
	// 	}
	// 	return runCli(jobParams, input, inputfile, inputurl, results);
	// }

	// static function runCli(
	// 	jobParams: BasicBatchProcessRequest,
	// 	?input :Array<String>,
	// 	?inputfile :Array<String>,
	// 	?inputurl :Array<String>,
	// 	?results: String,
	// 	?json :Bool = true) :Promise<CLIResult>
	// {
	// 	return runInternal(jobParams, input, inputfile, inputurl, results)
	// 		.then(function(submissionData :JobResult) {
	// 			//Write the client job file
	// 			var dateString = Date.now().format("%Y-%m-%d");
	// 			var resultsBaseDir = results != null ? results : 'results';
	// 			var clientJobFileDirPath = Path.join(resultsBaseDir, '${dateString}__${submissionData.jobId}');
	// 			FsExtended.ensureDirSync(clientJobFileDirPath);
	// 			var clientJobFilePath = Path.join(clientJobFileDirPath, Constants.SUBMITTED_JOB_RECORD_FILE);
	// 			FsExtended.writeFileSync(clientJobFilePath, Json.stringify(submissionData, null, '\t'));
	// 			var stdout = json ? Json.stringify(submissionData, null, '\t') : submissionData.jobId;
	// 			log(stdout);
	// 			return CLIResult.Success;
	// 		})
	// 		.errorPipe(function(err) {
	// 			trace(err);
	// 			return Promise.promise(CLIResult.ExitCode(1));
	// 		});
	// }

	// static function runInternal(
	// 	jobParams: BasicBatchProcessRequest,
	// 	?input :Array<String>,
	// 	?inputfile :Array<String>,
	// 	?inputurl :Array<String>,
	// 	?results: String,
	// 	?json :Bool = true) :Promise<JobResult>
	// {
	// 	// var dateString = Date.now().format("%Y-%m-%d");
	// 	// var resultsBaseDir = results != null ? results : 'results';

	// 	//Construct the inputs
	// 	var inputs :Array<ComputeInputSource> = [];
	// 	if (input != null) {
	// 		for (inputItem in input) {
	// 			var tokens = inputItem.split('=');
	// 			var inputName = tokens.shift();
	// 			inputs.push({
	// 				type: InputSource.InputInline,
	// 				value: tokens.join('='),
	// 				name: inputName
	// 			});
	// 		}
	// 	}
	// 	if (inputurl != null) {
	// 		for (url in inputurl) {
	// 			var tokens = url.split('=');
	// 			var inputName = tokens.shift();
	// 			var inputUrl = tokens.join('=');
	// 			inputs.push({
	// 				type: InputSource.InputUrl,
	// 				value: inputUrl,
	// 				name: inputName
	// 			});
	// 		}
	// 	}

	// 	jobParams.inputs = jobParams.inputs == null ? inputs :jobParams.inputs.concat(inputs);

	// 	var inputStreams = {};
	// 	if (inputfile != null) {
	// 		for (file in inputfile) {
	// 			var tokens = file.split('=');
	// 			var inputName = tokens.shift();
	// 			var inputPath = tokens.join('=');
	// 			var stat = Fs.statSync(inputPath);
	// 			if (!stat.isFile()) {
	// 				throw('ERROR no file $inputPath');
	// 			}
	// 			Reflect.setField(inputStreams, inputName, Fs.createReadStream(inputPath, {encoding:'binary'}));
	// 		}
	// 	}

	// 	var address = getServerAddress();
	// 	return Promise.promise(true)
	// 		.pipe(function(_) {
	// 			return ClientJSTools.postJob(address, jobParams, inputStreams);
	// 		});
	// }

	@rpc({
		alias:'wait',
		doc:'Wait on jobs. Defaults to all currently running jobs, or list jobs with wait <jobId1> <jobId2> ... <jobIdn>',
	})
	public static function wait(job :Array<String>) :Promise<CLIResult>
	{
		var host = getHost();
		var promises = [];
		var clientProxy = getProxy(host.rpcUrl());
		return Promise.promise(true)
			.pipe(function(_) {
				if (job == null || job.length == 0) {
					return clientProxy.jobs();
				} else {
					return Promise.promise(job);
				}
			})
			.pipe(function(jobIds) {
				var promises = if (jobIds != null) {
						jobIds.map(function(jobId) {
							return function() return ClientCompute.getJobResult(host, jobId);
						});
					} else {
						[];
					}
				return PromiseTools.chainPipePromises(promises)
					.then(function(jobResults) {
						return CLIResult.Success;
					});
			});
	}

	@rpc({
		alias:'terminate',
		doc:'Shut down the remote server(s) and workers, and delete server files locally',
	})
	public static function terminate(?confirm :Bool = false) :Promise<CLIResult>
	{
		return Promise.promise(CLIResult.Success);
	}

	@rpc({
		alias:'server-ping',
		doc:'Checks the server API'
	})
	public static function serverPing() :Promise<CLIResult>
	{
		var host = getHost();
		var url = 'http://$host/checks';
		return RequestPromises.get(url)
			.then(function(out) {
				var ok = out.trim() == SERVER_PATH_CHECKS_OK;
				log(ok ? 'OK' : 'FAIL');
				return ok ? CLIResult.Success : CLIResult.ExitCode(1);
			})
			.errorPipe(function(err) {
				log(Json.stringify({error:err}));
				return Promise.promise(CLIResult.ExitCode(1));
			});
	}

	@rpc({
		alias:'job-download',
		doc:'Given a jobId, downloads job results and data',
		args:{
			'job':{doc: 'JobId of the job to download'},
			'path':{doc: 'Path to put the results files. Defaults to ./<jobId>'}
		}
	})
	public static function jobDownload(job :JobId, ?path :String = null, ?includeInputs :Bool = false) :Promise<CLIResult>
	{
		if (job == null) {
			warn('Missing job argument');
			return Promise.promise(CLIResult.PrintHelpExit1);
		}
		// trace('jobDownload job=${job} path=${path} includeInputs=${includeInputs}');
		var downloadPath = path == null ? Path.join(Node.process.cwd(), job) : path;
		// trace('downloadPath=${downloadPath}');
		var outputsPath = Path.join(downloadPath, DIRECTORY_OUTPUTS);
		var inputsPath = Path.join(downloadPath, DIRECTORY_INPUTS);
		var host = getHost();
		// return Promise.promise(CLIResult.Success);
		// FsExtended.ensureDirSync(downloadPath);
		return doJobCommand(job, JobCLICommand.Result)
			.pipe(function(jobResult :JobResult) {
				if (jobResult == null) {
					warn('No job id: $job');
					return Promise.promise(CLIResult.ExitCode(1));
				}
				var localStorage = ccc.storage.ServiceStorageLocalFileSystem.getService(downloadPath);
				var promises = [];
				for (source in [STDOUT_FILE, STDERR_FILE, 'resultJson']) {
					var localPath = source == 'resultJson' ? 'result.json' : source;
					var sourceUrl :String = Reflect.field(jobResult, source);
					if (!sourceUrl.startsWith('http')) {
						sourceUrl = 'http://$host/$sourceUrl';
					}
					var fp = function() {
						log('Downloading $sourceUrl => $downloadPath/$localPath');
						return localStorage.writeFile(localPath, Request.get(sourceUrl))
							.errorPipe(function(err) {
								try {
									FsExtended.deleteFileSync(Path.join(downloadPath, localPath));
								} catch(deleteFileErr :Dynamic) {
									//Ignored
								}
								return Promise.promise(true);
							});
					}
					promises.push(fp);
				}
				var outputStorage = ccc.storage.ServiceStorageLocalFileSystem.getService(outputsPath);
				for (source in jobResult.outputs) {
					var localPath = source;
					var remotePath = Path.join(jobResult.outputsBaseUrl, source);
					if (!remotePath.startsWith('http')) {
						remotePath = 'http://$host/$remotePath';
					}
					var p = function() {
						log('Downloading $remotePath => $outputsPath/$localPath');
						return outputStorage.writeFile(localPath, Request.get(remotePath))
							.errorPipe(function(err) {
								try {
									FsExtended.deleteFileSync(Path.join(outputsPath, localPath));
								} catch(deleteFileErr :Dynamic) {
									//Ignored
								}
								return Promise.promise(true);
							});
					}
					promises.push(p);
				}
				if (includeInputs) {
					var inputStorage = ccc.storage.ServiceStorageLocalFileSystem.getService(inputsPath);
					for (source in jobResult.inputs) {
						var localPath = source;
						var remotePath = Path.join(jobResult.inputsBaseUrl, source);
						if (!remotePath.startsWith('http')) {
							remotePath = 'http://$host/$remotePath';
						}
						var p = function() {
							log('Downloading $remotePath => $inputsPath/$localPath');
							return inputStorage.writeFile(localPath, Request.get(remotePath))
								.errorPipe(function(err) {
									try {
										FsExtended.deleteFileSync(Path.join(inputsPath, localPath));
									} catch(deleteFileErr :Dynamic) {
										//Ignored
									}
									return Promise.promise(true);
								});
						}
						promises.push(p);
					}
				}

				return PromiseTools.chainPipePromises(promises)
					.thenVal(CLIResult.Success);
			});
	}

	@rpc({
		alias:'test',
		doc:'Test a simple job with a cloud-compute-cannon server'
	})
	public static function test() :Promise<CLIResult>
	{
		var rand = Std.string(Std.int(Math.random() * 1000000));
		var stdoutText = 'HelloWorld$rand';
		var outputText = 'output$rand';
		var outputFile = 'output1';
		var inputFile = 'input1';
		var command = ["python", "-c", 'data = open("/$DIRECTORY_INPUTS/$inputFile","r").read()\nprint(data)\nopen("/$DIRECTORY_OUTPUTS/$outputFile", "w").write(data)'];
		var image = 'elyase/staticpython';

		var jobParams :BasicBatchProcessRequest = {
			image: image,
			cmd: command,
			parameters: {cpus:1, maxDuration:60*1000*10},
			inputs: [],
			outputsPath: 'someTestOutputPath/outputs',
			inputsPath: 'someTestInputPath/inputs',
			wait: true
		};
		return runInternal(jobParams, ['$inputFile=input1$rand'], [], [], './tmp/results')
			.pipe(function(jobResult) {
				if (jobResult != null && jobResult.exitCode == 0) {
					var address = getServerAddress();
					return Promise.promise(true)
						.pipe(function(_) {
							return RequestPromises.get('http://' + jobResult.stdout)
								.then(function(stdout) {
									log('stdout=${stdout.trim()}');
									Assert.that(stdout.trim() == stdoutText);
									return true;
								});
						});
				} else {
					log('jobResult is null $jobResult');
					return Promise.promise(false);
				}
			})
			.then(function(success) {
				if (!success) {
					//Until waiting is implemented
					// log('Failure');
				}
				return success ? CLIResult.Success : CLIResult.ExitCode(1);
			})
			.errorPipe(function(err) {
				log(err);
				return Promise.promise(CLIResult.ExitCode(1));
			});
	}

	@rpc({
		alias:'job-run-local',
		doc:'Download job inputs and run locally. Useful for replicating problematic jobs.',
		args:{
			'path':{doc: 'Base path for the job inputs/outputs/results'}
		}
	})
	public static function runRemoteJobLocally(job :JobId, ?path :String) :Promise<CLIResult>
	{
		var host = getHost();
		var downloadPath = path == null ? Path.join(Node.process.cwd(), job) : path;
		downloadPath = Path.normalize(downloadPath);
		var inputsPath = Path.join(downloadPath, DIRECTORY_INPUTS);
		var outputsPath = Path.join(downloadPath, DIRECTORY_OUTPUTS);
		return doJobCommand(job, JobCLICommand.Definition)
			.pipe(function(jobDef :DockerJobDefinition) {
				trace('${jobDef}');
				FsExtended.deleteDirSync(outputsPath);
				FsExtended.ensureDirSync(outputsPath);
				var localStorage = ccc.storage.ServiceStorageLocalFileSystem.getService(downloadPath);
				var promises = [];
				//Write inputs
				var inputsStorage = ccc.storage.ServiceStorageLocalFileSystem.getService(inputsPath);
				for (source in jobDef.inputs) {
					var localPath = source;
					var remotePath = 'http://' + host + '/' + jobDef.inputsPath + source;
					var p = inputsStorage.writeFile(localPath, Request.get(remotePath))
						.errorPipe(function(err) {
							Node.process.stderr.write(err + '\n');
							return Promise.promise(true);
						});
					promises.push(p);
				}
				return Promise.whenAll(promises)
					.pipe(function(_) {
						var promise = new DeferredPromise();
						var dockerCommand = ['run', '--rm', '-v', inputsPath + ':/' + DIRECTORY_INPUTS, '-v', outputsPath + ':/' + DIRECTORY_OUTPUTS, jobDef.image.value];
						var dockerCommandForConsole = dockerCommand.concat(jobDef.command.map(function(s) return '"$s"'));
						dockerCommand = dockerCommand.concat(jobDef.command);
						trace('Command to replicate the job:\n\ndocker ${dockerCommandForConsole.join(' ')}\n');
						var process = ChildProcess.spawn('docker', dockerCommand);
						var stdout = '';
						var stderr = '';
						process.stdout.on(ReadableEvent.Data, function(data) {
							stdout += data + '\n';
							// console.log('stdout: ${data}');
						});
						process.stderr.on(ReadableEvent.Data, function(data) {
							stderr += data + '\n';
							// console.error('stderr: ${data}');
						});
						process.on('close', function(code) {
							console.log('EXIT CODE: ${code}');
							console.log('STDOUT:\n\n$stdout\n');
							console.log('STDERR:\n\n$stderr\n');
							promise.resolve(true);
						});
						return promise.boundPromise;
					})
					.thenVal(CLIResult.Success);
			});
	}

	static function doJobCommand<T>(job :JobId, command :JobCLICommand) :Promise<T>
	{
		var host = getHost();
		var clientProxy = getProxy(host.rpcUrl());
		return clientProxy.doJobCommand(command, job)
			.then(function(out) {
				var result :TypedDynamicObject<JobId, T> = cast out;
				var jobResult :T = result[job];
				return jobResult;
			});
	}

	static function getServerAddress() :Host
	{
		return CliTools.getServerHost();
	}

	static function jsonString(blob :Dynamic) :String
	{
		return Json.stringify(blob, null, '\t');
	}

	public static function validateServerAndClientVersions() :Promise<Bool>
	{
		return getVersions()
			.then(function(v) {
				return v.server == null || (v.server.npm == v.client.npm);
			});
	}

	public static function getVersions() :Promise<{client:ClientVersionBlob,server:ServerVersionBlob}>
	{
		var clientVersionBlob :ClientVersionBlob = {
			npm: Json.parse(Resource.getString('package.json')).version,
			compiler: Version.getHaxeCompilerVersion()
		}
		var result = {
			client:clientVersionBlob,
			server:null
		}
		var host = getHost();
		if (host != null) {
			var clientProxy = getProxy(host.rpcUrl());
			return clientProxy.serverVersion()
				.then(function(serverVersionBlob) {
					result.server = serverVersionBlob;
					return result;
				});
		} else {
			return Promise.promise(result);
		}
	}

	inline static function log(message :Dynamic)
	{
#if nodejs
		js.Node.console.log(message);
#else
		trace(message);
#end
	}

	inline static function warn(message :Dynamic)
	{
#if nodejs
		js.Node.console.log(js.npm.clicolor.CliColor.bold(js.npm.clicolor.CliColor.red(message)));
#else
		trace(message);
#end
	}

	static var console = {
		log: function(s) {
			js.Node.process.stdout.write(s + '\n');
		},
		error: function(s) {
			js.Node.process.stderr.write(s + '\n');
		},
	}
}