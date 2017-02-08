package ccc.compute.server.execution;

/**
 * Represents a running job in a docker container.
 * Actively monitors the job.
 * TODO: Also can resume
 */

import util.DockerTools;

import ccc.compute.server.FluentTools;
import ccc.compute.server.execution.BatchComputeDocker;

import js.npm.RedisClient;
import js.npm.ssh2.Ssh;

import ccc.storage.*;

import util.streams.StreamTools;
import util.SshTools;

using util.RedisTools;
using ccc.compute.server.JobTools;
using ccc.compute.server.workers.WorkerTools;
using util.MapTools;

class JobExecutionTools
{
	public static function writeJobResults(job :QueueJobDefinitionDocker, fs :ServiceStorage, batchJobResult :BatchJobResult, finishedStatus :JobFinishedStatus) :Promise<JobResult>
	{
		var jobStorage = fs.clone();
		/* The e.g. S3 URL. Otherwise empty */
		var externalBaseUrl = fs.getExternalUrl();

		var appendStdOut = job.item.appendStdOut == true;
		var appendStdErr = job.item.appendStdErr == true;

		var jobResult :JobResult = {
			jobId: job.id,
			status: finishedStatus,
			exitCode: batchJobResult.exitCode,
			stdout: fs.getExternalUrl(job.item.stdoutPath()),
			stderr: fs.getExternalUrl(job.item.stderrPath()),
			resultJson: externalBaseUrl + job.item.resultJsonPath(),
			inputsBaseUrl: externalBaseUrl + job.item.inputDir(),
			outputsBaseUrl: externalBaseUrl + job.item.outputDir(),
			inputs: job.item.inputs,
			outputs: batchJobResult.outputFiles,
			error: batchJobResult.error,
			definition: job.item,
			stats: job.stats
		};

		Log.debug({jobid:job.id, exitCode:batchJobResult.exitCode});
		Log.trace(Json.stringify(jobResult, null, '  '));
		var jobResultsStorage = jobStorage.appendToRootPath(job.item.resultDir());
		return Promise.promise(true)
			.pipe(function(_) {
				if (batchJobResult.copiedLogs) {

					return jobResultsStorage.exists(STDOUT_FILE)
						.pipe(function(exists) {
							if (!exists) {
								jobResult.stdout = null;
								return Promise.promise(true);
							} else {
								if (appendStdOut) {
									return jobResultsStorage.readFile(STDOUT_FILE)
										.pipe(function(stream) {
											return StreamPromises.streamToString(stream)
												.then(function(stdoutString) {
													if (stdoutString != null) {
														Reflect.setField(jobResult, 'stdout', stdoutString.split('\n'));
													} else {
														Reflect.setField(jobResult, 'stdout', null);
													}
													return true;
												})
												.errorPipe(function(err) {
													Log.error(Json.stringify(err));
													return Promise.promise(true);
												});
										});
								} else {
									return Promise.promise(true);
								}
							}

							return jobResultsStorage.exists(STDERR_FILE);
						})
						.pipe(function(exists) {
							if (!exists) {
								jobResult.stderr = null;
								return Promise.promise(true);
							} else {
								if (appendStdErr) {
									return jobResultsStorage.readFile(STDERR_FILE)
										.pipe(function(stream) {
											return StreamPromises.streamToString(stream)
												.then(function(stderrString) {
													if (stderrString != null) {
														Reflect.setField(jobResult, 'stderr', stderrString.split('\n'));
													} else {
														Reflect.setField(jobResult, 'stderr', null);
													}
													return true;
												})
												.errorPipe(function(err) {
													Log.error(Json.stringify(err));
													return Promise.promise(true);
												});
										});
								} else {
									return Promise.promise(true);
								}
							}
						});
				} else {
					jobResult.stdout = null;
					jobResult.stderr = null;
					return Promise.promise(true);
				}
			})
			.pipe(function(_) {
				return jobResultsStorage.writeFile(RESULTS_JSON_FILE, StreamTools.stringToStream(Json.stringify(jobResult)));
			})
			.pipe(function(_) {
				if (externalBaseUrl != '') {
					return promhx.RetryPromise.pollRegular(function() {
						return jobResultsStorage.readFile(RESULTS_JSON_FILE)
							.pipe(function(readable) {
								return StreamPromises.streamToString(readable);
							})
							.then(function(s) {
								return null;
							});
						}, 10, 50, '${RESULTS_JSON_FILE} check', false)
						.then(function(resultsjson) {
							return null;
						});
				} else {
					return Promise.promise(null);
				}
			})
			.then(function(_) {
				return jobResult;
			});
	}

	public static function checkMachine(worker :WorkerDefinition) :Promise<Bool>
	{
		return cloud.MachineMonitor.checkMachine(worker.docker, worker.ssh);
	}

	// public static function catchExecuteErrorHandler(job :QueueJobDefinitionDocker, fs :ServiceStorage, log :AbstractLogger) :Dynamic->Void;
	// {
	// 	return function(err) {
	// 		log.error(try {Json.stringify(err);} catch(_:Dynamic) {err;});

	// 		//Write job as a failure
	// 		//This should actually never happen, or the failure
	// 		//should be handled
	// 		var batchJobResult = {exitCode:-1, error:err, copiedLogs:false};
	// 		log.error({exitCode:-1, error:err, JobStatus:null, JobFinishedStatus:null});
	// 		writeJobResults(job, fs, batchJobResult, JobFinishedStatus.Failed)
	// 			.then(function(_) {
	// 				log.debug({job:job.id, message:"Finished writing job"});
	// 				return finishJob(JobFinishedStatus.Failed, Std.string(err));
	// 			})
	// 			.catchError(function(err) {
	// 				log.error({error:err, message:"Failed to write job results", jobId:job.id});
	// 			});
	// 	}
	// }
}