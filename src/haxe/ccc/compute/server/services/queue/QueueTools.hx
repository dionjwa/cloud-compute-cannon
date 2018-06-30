package ccc.compute.server.services.queue;

import ccc.QueueJobDefinition;
import ccc.compute.worker.QueueJobs;
import ccc.compute.worker.QueueJobResults;

import js.npm.bull.Bull;

class QueueTools
{
	public static function getQueues(injector :Injector) :Queues
	{
		return injector.getValue(ccc.compute.server.services.queue.Queues);
	}

	public static function getQueueSizes(injector :Injector) :Promise<{cpu:BullJobCounts,gpu:BullJobCounts}>
	{
		var queues :Queues = getQueues(injector);
		return Promise.whenAll([queues.cpu.getJobCounts().promhx(), queues.gpu.getJobCounts().promhx()])
			.then(function(jobCountsArray) {
				return {
					cpu: jobCountsArray[0],
					gpu: jobCountsArray[1]
				};
			});
	}

	public static function addJob(injector :Injector, job :QueueJobDefinition, ?log :AbstractLogger) :Promise<Bool>
	{
		var queue = getQueues(injector).getQueue(job.parameters);
		return addJobToQueue(queue, job, log);
	}

	public static function addJobToQueue(queue :Queue<QueueJobDefinition, QueueJobResults>, job :QueueJobDefinition, ?log :AbstractLogger) :Promise<Bool>
	{
		Assert.notNull(queue);
		log = log == null ? Log.log : log;
		job.attempt = 1;
		job.parameters = ServiceBatchComputeTools.ensureGoodJobParameters(job.parameters);
		return switch(job.type) {
			case compute:
				Promise.promise(true)
					.pipe(function(_) {
						var def :DockerBatchComputeJob = job.item;
						log.info(LogFieldUtil.addJobEvent({jobId:job.id, attempt:1, type:job.type, message:'via ProcessQueue', meta: def.meta, gpu:job.parameters.gpu, cpu:job.parameters.cpus}, JobEventType.ENQUEUED));

						return Promise.whenAll([
							Jobs.setJob(job.id, job.item),
							Jobs.setJobParameters(job.id, job.parameters),
							JobStatsTools.jobEnqueued(job.id, job.item)
								.thenTrue()
						]);
					})
					.then(function(_) {
						Assert.notNull(queue);
						//Not removed automatically. Can be manually removed, or by the cron job cleanup
						//On a cleanup event, job is added to cleanup queue (to ensure all bits are removed)
						//Actually belay that order. Bull queue jobs ARE auto deleted, since they don't have
						//the right set of events to cancel
						queue.add(job, {jobId:job.id, priority:(job.priority ? 1 : 1000), removeOnComplete:true, removeOnFail:true});
						return true;
					});
			case turbo:
				var def :BatchProcessRequestTurboV2 = job.item;
				log.info(LogFieldUtil.addJobEvent({jobId:job.id, attempt:1, type:job.type, message:'via ProcessQueue', meta: def.meta, gpu:job.parameters.gpu, cpu:job.parameters.cpus}, JobEventType.ENQUEUED));
				var maxTime = 300000;//5 minutes max
				Assert.notNull(queue);
				//This type of job does not touch file storage, and only lives in the bull
				//queue so can be safely removed when finished/failed.
				queue.add(job, {jobId:job.id, priority:1, removeOnComplete:true, removeOnFail:true, timeout:maxTime});
				Promise.promise(true);
		}
	}

	public static function addListeners(name :BullQueueNames, queue :Queue<Dynamic, Dynamic>)
	{
		queue.on('global:${QueueEvent.Error}', function(err) {
			Log.error({e:QueueEvent.Error, queue:name, error:Json.stringify(err)});
		});

		queue.on('global:${QueueEvent.Active}', function(jobId) {
			Log.debug({e:QueueEvent.Active, queue:name, jobId:jobId});
		});

		queue.on('global:${QueueEvent.Stalled}', function(jobId) {
			Log.warn({e:QueueEvent.Stalled, queue:name, jobId:jobId});
		});

		queue.on('global:${QueueEvent.Progress}', function(jobId, progress) {
			Log.debug({e:QueueEvent.Progress, queue:name, jobId:jobId, progress:progress});
		});

		queue.on('global:${QueueEvent.Completed}', function(jobId :String, result :Dynamic) {
			Log.debug({e:QueueEvent.Completed, queue:name, jobId:jobId, result:result});
		});

		queue.on('global:${QueueEvent.Failed}', function(jobId :String, error :js.Error) {
			Log.warn({e:QueueEvent.Failed, jobId:jobId, error:error});
		});

		queue.on('global:${QueueEvent.Paused}', function() {
			Log.warn({e:QueueEvent.Paused, queue:name});
		});

		queue.on('global:${QueueEvent.Resumed}', function(jobId) {
			Log.debug({e:QueueEvent.Resumed, queue:name, jobId:jobId});
		});

		queue.on('global:${QueueEvent.Cleaned}', function(jobs, status) {
			Log.debug({e:QueueEvent.Cleaned, queue:name, jobIds:jobs.map(function(j) return j.data.id).array()});
			return null;
		});
	}

	public static function addBullDashboard(injector :Injector)
	{
		var redisHost :String = ServerConfig.REDIS_HOST;
		var redisPort :Int = ServerConfig.REDIS_PORT;
		var bullArena = new js.npm.bullarena.BullArena(
			{
				queues:[
					{
						name: BullQueueNames.SingleMessageQueue,
						port: redisPort,
						host: redisHost,
						hostId: redisHost
					},
					{
						name: BullQueueNames.JobQueue,
						port: redisPort,
						host: redisHost,
						hostId: redisHost
					},
					{
						name: BullQueueNames.JobQueueGpu,
						port: redisPort,
						host: redisHost,
						hostId: redisHost
					},
					{
						name: BullQueueNames.CronMessageQueue,
						port: redisPort,
						host: redisHost,
						hostId: redisHost
					}
				]
			},
			{
				basePath: '/dashboard',
				disableListen: true
			}
		);

		var app :js.npm.express.Application = injector.getValue(js.npm.express.Application);
		var router = js.npm.express.Express.GetRouter();
		router.use('/', cast bullArena);
		app.use(cast router);
	}
}