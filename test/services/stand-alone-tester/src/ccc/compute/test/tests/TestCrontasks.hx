package ccc.compute.test.tests;

import js.npm.bull.Bull;

import ccc.compute.server.services.queue.BullQueueJobTools;
import ccc.compute.server.services.queue.Queues;

class TestCrontasks
	extends ServerAPITestBase
{
	/**
	 * It's quite a PITA to actually regularly test cron functionality
	 * so I'm skipping that part and just testing the final function that
	 * actually does the cleanup.
	 */
	@timeout(120000)
	public function testCrontaskCleanJobsFunction() :Promise<Bool>
	{
		var queues :Queues = ServerTestTools.getQueues(injector);

		var routes = ProxyTools.getProxy(_serverHostRPCAPI);

		var jobRequest :BasicBatchProcessRequest = {
			image: DOCKER_IMAGE_DEFAULT,
			cmd: ['echo', 'foo'],
			inputs: [],
			wait: true
		};

		var jobCount = 4;
		var jobIds :Array<JobId>;

		return Promise.promise(true)
			//Make sure no other jobs are running from previous tests
			.pipe(function(_) {
				return BullQueueTestTools.waitUntilQueueEmpty(queues.cpu);
			})
			//Submit <jobCount> jobs
			.pipe(function(_) {
				return Promise.whenAll([for (i in 0...jobCount) routes.submitJobJson(jobRequest)]);
			})
			//Get the job ids
			.pipe(function(jobResults) {
				jobIds = jobResults.map(function (j) return j.jobId);
				return Promise.promise(true);
			})
			//Validate the finished jobs are correctly sorted by time finished
			.pipe(function(_) {
				var now = Date.now().getTime();
				return JobStatsTools.getJobsFinishedBetween(now - Ms.parse('500ms'), now)
					.then(function(thoseJobIds) {
						for (jobId in thoseJobIds) {
							assertTrue(jobIds.has(jobId));
						}
					});
			})
			//Validate the queues are empty
			.pipe(function(_) {
				return QueueTools.getQueueSizes(injector)
					.then(function(queueSizeData) {
						if (queueSizeData.cpu.waiting != 0 || queueSizeData.cpu.active != 0) {
							traceRed(Json.stringify(queueSizeData));
						}
						assertEquals(queueSizeData.cpu.waiting, 0);
						assertEquals(queueSizeData.cpu.active, 0);
					});
			})
			//Run the clean task, and wait until the message queue is empty
			.pipe(function(_) {
				var queues :Queues = injector.getValue(Queues);
				return CronTasks.cleanOldJobDataInternal(queues, '500ms');
			})
			.pipe(function(_) {
				return BullQueueTestTools.waitUntilQueueEmpty(queues.message);
			})
			//Validate the jobs are deleted
			.pipe(function(_) {
				var now = Date.now().getTime();
				return JobStatsTools.getFinishedJobsOlderThan(Ms.parse('5s'))
					.then(function(thoseJobIds) {
						for (jobId in jobIds) {
							assertFalse(thoseJobIds.has(jobId));
						}
					}).thenTrue();
			})
			.thenTrue();
	}

	/**
	 * The enqueued job removal should not fail just because a job doesn't
	 * exist. Failures should only be reported if the first job cleanup
	 * fails under some conditions.
	 */
	@timeout(120000)
	//Force access to this private method
	@:access(ccc.compute.server.services.queue.Queues.performJobRemoval)
	public function testCrontaskCleanJobsNonExistentJobDoesErrorBullJob() :Promise<Bool>
	{
		var queues :Queues = ServerTestTools.getQueues(injector);

		var fs = StorageTools.getStorageLocalDefault();
		injector.map(ServiceStorage).toValue(fs);

		var jobDef :DockerBatchComputeJob = {
			id: 'fakeJobId',
			image: null,
		}

		var promise = new DeferredPromise();

		//This job doesn't actually exist, so check no error is returned.
		queues.performJobRemoval(jobDef, function(err, result) {
			if (err != null) {
				traceRed(err);
			}
			assertTrue(err == null);
			promise.resolve(true);
		});

		return promise.boundPromise;
	}

	// The CronTasks logic works as expected from manual observation
	// and tests, but testing it has proved annoyingly cumbersome.
	// I'm going to punt on this test for now.
	// @timeout(4000)
	// public function testCorrectCrontasks() :Promise<Bool>
	// {
	// 	var redisHost :String = ServerTesterConfig.REDIS_HOST;
	// 	var redisPort :Int = ServerTesterConfig.REDIS_PORT;
	// 	var cronQueue :Queue<CronTaskQueueJobData, String> = new js.npm.bull.Bull.Queue(BullQueueNames.CronMessageQueue, {redis:{port:ServerConfig.REDIS_PORT, host:ServerConfig.REDIS_HOST}});

	// 	return cronQueue.getRepeatableJobs().promhx()
	// 		.then(function(repeatableJobs) {
	// 			if (repeatableJobs.length != CronTasks.tasks.count()) {
	// 				traceRed('repeatableJobs=${Json.stringify(repeatableJobs)}');
	// 			}
	// 			assertEquals(repeatableJobs.length, CronTasks.tasks.count());
	// 			for (job in repeatableJobs) {
	// 				if (!CronTasks.tasks.exists(job.id)) {
	// 					traceRed('repeatableJobs=${Json.stringify(repeatableJobs)}');
	// 				}
	// 				assertTrue(CronTasks.tasks.exists(job.id));
	// 			}
	// 		})
	// 		.then(function(_) cronQueue.close())
	// 		.thenTrue();
	// }
}
