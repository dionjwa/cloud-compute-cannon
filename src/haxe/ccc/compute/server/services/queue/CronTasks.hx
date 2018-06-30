package ccc.compute.server.services.queue;

/**
 * Repeated tasks. These are mostly cleanup/maintenance/metrics
 * tasks that should only be executed by a single machine at
 * the specified time interval (crontab format).
 */

import js.npm.bull.Bull;
import ccc.QueueJobDefinition;
import ccc.compute.worker.QueueJobResults;

// cron is a cron string https://github.com/OptimalBits/bull/blob/master/REFERENCE.md#queueadd
// task is the function to execute
typedef CronTask = {
	cron :String,
	task :Injector->Promise<String>,
}

typedef CronTaskQueueJobData = {
	cronId :String,
}

class CronTasks
{
	//Cron Task definitions
	public static var tasks :Map<String, CronTask> = [
		'clean-old-job-data' => {
			cron: ServerConfig.CLEAN_OLD_JOBS_CRON,
			task: cleanOldJobData
		},
	];

	/**
	 * Update and manage the bull job cron tasks.
	 */
	public static function init(injector :Injector) :Promise<Bool>
	{
		Assert.notNull(injector);
		var redis :RedisClient = injector.getValue(RedisClient);
		Assert.notNull(redis);
		//Create a queue to add and process the cron tasks
		var cronQueue :Queue<CronTaskQueueJobData, String> = new js.npm.bull.Bull.Queue(BullQueueNames.CronMessageQueue, {redis:{port:ServerConfig.REDIS_PORT, host:ServerConfig.REDIS_HOST}});
		//Completely arbitrary guesstimate, not expecting to ever exceed this.
		var concurrentCronTasks = 10;
		cronQueue.process(concurrentCronTasks, cast function (job: Job<CronTaskQueueJobData>, done :Done2<String>) :Void {
			var cronTask :CronTaskQueueJobData = job.data;
			var cronTaskKey :String = cronTask.cronId;
			try {
				tasks[cronTaskKey].task(injector)
					.then(function(result :String) {
						done(null, null);
					})
					.catchError(function(err) {
						Log.error({cron:cronTaskKey, error:err});
						done(err, null);
					});
			} catch(err :Dynamic) {
				Log.error({error:err, message:'Failure in cron task=$cronTaskKey'});
			}
		});

		//Remove all the existing cron tasks
		//and replace them with the current set
		//Even if many instances start concurrently
		//there will always be one last instance
		//creating all tasks anew. Collisions can occur
		//when creating the task so warn.
		return cronQueue.getRepeatableJobs().promhx()
			.pipe(function(jobs) {
				return Promise.whenAll(
					jobs.map(function(j) return cronQueue.removeRepeatable(j).promhx().thenTrue()
						.errorPipe(function(err) {
							Log.warn({error:err, message:'Removing repeatable job, expect this error to occur sometimes due to multiple instance updates.'});
							return Promise.promise(true);
						})));
			})
			.pipe(function(_) {
				var keys :Array<String> = [for (i in tasks.keys()) i];
				var promises :Array<Promise<Dynamic>> = keys.map(function(taskId :String) {
					var taskDef = tasks[taskId];
					return cronQueue.add(
						//Job definition CronTaskQueueJobData
						{cronId: taskId},
						//Job params
						{
							jobId: taskId,
							attempts: 3,
							repeat: {
								cron: taskDef.cron,
								tz: 'America/Los_Angeles',
							},
							timeout: Ms.parse('2m'),//No job should take longer than this.
							removeOnComplete: true,
							removeOnFail	: true,
						}).promhx().thenTrue();
				});
				return Promise.whenAll(promises);
			})
			.thenTrue();
	}

	public static function cleanOldJobData(injector :Injector) :Promise<String>
	{
		var queues :Queues = injector.getValue(Queues);
		return cleanOldJobDataInternal(queues, ServerConfig.CLEAN_OLD_JOBS_MAX_AGE);
	}

	public static function cleanOldJobDataInternal(queues :Queues, olderThanDurationString :String) :Promise<String>
	{
		var now = Date.now().getTime();
		var durationMs :Float = Ms.parse(olderThanDurationString);
		Assert.that(now > durationMs);
		var someTimeAgo = now - durationMs;

		return JobStatsTools.getFinishedJobsOlderThan(someTimeAgo)
			.pipe(function(jobIds) {
				return Promise.whenAll(
					jobIds.map(function(jobId) {
						return Jobs.getJob(jobId)
							.then(function(jobDef :DockerBatchComputeJob) {
								if (jobDef == null) {
									return;
								}
								queues.enqueueJobCleanup(jobDef);
							});
					})
				).then(function(_) {
					Log.info({cron:'clean-old-job-data', jobsCleaned:jobIds.length});
					return 'Jobs cleaned ${jobIds.length}';
				});
			});
	}
}
