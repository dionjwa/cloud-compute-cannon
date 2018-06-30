package ccc.compute.test.tests;

import js.npm.bull.Bull;

import ccc.compute.server.services.queue.BullQueueJobTools;
import ccc.compute.server.services.queue.*;

class TestRedis
	extends ServerAPITestBase
{
	@inject public var redis :RedisClient;

	//Used by the redis logger to reliably deliver logs and metrics
	//instead of building my own reliable delivery.
	@timeout(4000)
	public function testAddToBullQueueWithinRedisLua() :Promise<Bool>
	{
		var promise = new DeferredPromise();
		var redisHost :String = ServerTesterConfig.REDIS_HOST;
		var redisPort :Int = ServerTesterConfig.REDIS_PORT;
		var queueName = 'TEST-QUEUE';
		var jobId = null;
		var messageQueue :Queue<BullQueueSingleMessageQueueAction, String> = new js.npm.bull.Bull.Queue(queueName, {redis:{port:redisPort, host:redisHost}});
		var jobsProcessed = [];

		function checkExistingJobs() {
			if (jobId != null) {
				for (jobData in jobsProcessed) {
					if (jobData.id == jobId) {
						promise.resolve(true);
					}
				}
			}
		}

		var processor = function(jobData, done) {
			done(null, null);
			jobsProcessed.push(jobData);
			checkExistingJobs();
		}
		messageQueue.process(cast processor);
		// For debugging
		// QueueTools.addListeners(queueName, messageQueue);
		assertNotNull(redis);
		return BullQueueJobTools.init(redis)
			.pipe(function(_) {
				var jobOptions :JobOptions = {removeOnComplete:true, removeOnFail:true};
				return BullQueueJobTools.addBullJobInsideRedis(queueName, {}, jobOptions, jobId)
					.pipe(function(id) {
						jobId = id;
						return promise.boundPromise;
					});
			})
			.then(function(_) {
				messageQueue.close();
			})
			.thenTrue();
	}
}
