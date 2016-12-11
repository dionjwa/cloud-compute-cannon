package ccc.compute.mode.singleworker;

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
class ProcessQueue
{
	inline public static var JOB_QUEUE_NAME = "job_queue";
	public static function createProcessor(
		redis :RedisConnection,
		parallelCpus :Int,
		remoteStorage :ServiceStorage,
		workerStorage :ServiceStorage,
		log :AbstractLogger) :Queue<QueueJobDefinitionDocker,JobResult>
	{
		var queue = new Queue('testQueue', "fakeRedisConnectionString");
		queue.process(parallelCpus, createJobProcesser(redis, remoteStorage, workerStorage, log));

		return queue;
	}

	static function createJobProcesser(redis :RedisConnection, remoteStorage :ServiceStorage, workerStorage :ServiceStorage, log :AbstractLogger) :Job<QueueJobDefinitionDocker>->Done2<JobResult>->Void
	{
		return function(job, done) {
			
		}
	}

	// public function new(parallelCpus :Int, redis :RedisConnection)
	// {

	// }


}