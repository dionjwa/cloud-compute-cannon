package ccc.compute.server.execution.singleworker;

import ccc.compute.server.execution.JobExecutionTools.*;
import ccc.storage.ServiceStorage;

import js.npm.bull.Bull;

/**
 * The main class for pulling jobs off the queue and
 * executing them.
 *
 * Currently this only supports local job execution
 * meaning this process is expecting to be in the
 * same process as the worker.
 */

typedef RedisConnection = {
	var host :String;
	@:optional var port :Int;
	@:optional var opts :Dynamic;
}

typedef QueueArguments = {
	var redis: RedisConnection;
	var log :AbstractLogger;
}

typedef ProcessArguments = { >QueueArguments,
	@:optional var cpus :Int;
	var remoteStorage :ServiceStorage;
	var workerStorage :ServiceStorage;
}

class ProcessQueue
{
	inline public static var JOB_QUEUE_NAME = "job_queue";
	inline static var DEFAULT_REDIS_PORT = 6379;

	public static function getQueue(args :QueueArguments) :Queue<QueueJobDefinitionDocker,JobResult>
	{
		var redisHost :String = args.redis.host;
		var redisPort :Int = args.redis.port != null ? args.redis.port : DEFAULT_REDIS_PORT;
		return new Queue(JOB_QUEUE_NAME, redisPort, redisHost);
	}

	public static function createProcessor(args :ProcessArguments) :Queue<QueueJobDefinitionDocker,JobResult>
	{
		var redisHost :String = args.redis.host;
		var redisPort :Int = args.redis.port != null ? args.redis.port : DEFAULT_REDIS_PORT;
		var cpus :Int = args.cpus != null ? args.cpus : 1;
		var queue :Queue<QueueJobDefinitionDocker,JobResult> = new Queue(JOB_QUEUE_NAME, redisPort, redisHost);
		queue.process(cpus, createJobProcesser(args.redis, args.remoteStorage, args.workerStorage, args.log));
		return queue;
	}

	static function createJobProcesser(redis :RedisConnection, remoteStorage :ServiceStorage, workerStorage :ServiceStorage, log :AbstractLogger) :Job<QueueJobDefinitionDocker>->Done2<JobResult>->Void
	{
		var redis = RedisClient.createClient(redis.port, redis.host);
		return function(queueJob :Job<QueueJobDefinitionDocker>, done) {
			var job = queueJob.data;
			var executeBlob = BatchComputeDocker.executeJob(redis, job, remoteStorage, workerStorage, log);

			executeBlob.promise
				.then(function(batchJobResult) {
					log.debug('Queue job success');
					return writeJobResults(job, remoteStorage, batchJobResult, JobFinishedStatus.Success)
						.then(function(jobResult) {
							done(null, jobResult);//Success
						});
				})
				.catchError(function(err) {
					log.error({error:err});
					// log.error(try {Json.stringify(err);} catch(_:Dynamic) {err;});

					//Write job as a failure
					//This should actually never happen, or the failure
					//should be handled
					var batchJobResult = {exitCode:-1, error:err, copiedLogs:false};
					// log.error({exitCode:-1, error:err, JobStatus:null, JobFinishedStatus:null});
					writeJobResults(job, remoteStorage, batchJobResult, JobFinishedStatus.Failed)
						.then(function(_) {
							log.debug({job:job.id, message:"Finished writing job"});
							done(batchJobResult, null);
							// return finishJob(JobFinishedStatus.Failed, Std.string(err));
						})
						.catchError(function(err) {
							log.error({error:err, message:"Failed to write job results", jobId:job.id});
						});
				});
		}
	}

	// public function new(parallelCpus :Int, redis :RedisConnection)
	// {

	// }


}