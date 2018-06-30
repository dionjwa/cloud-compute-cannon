package ccc.compute.server.services.queue;

import js.npm.bull.Bull;
import ccc.QueueJobDefinition;
import ccc.compute.worker.QueueJobResults;

/**
 * Holds references to queues and manages handlers for non-job queues.
 * Job processing from the cpu+gpu queues is handled by QueueJobs as
 * there is much more state and error handling.
 */
class Queues
{
	@inject public var injector :Injector;
	public var cpu :Queue<QueueJobDefinition, QueueJobResults>;
	public var gpu :Queue<QueueJobDefinition, QueueJobResults>;
	public var message :Queue<BullQueueSingleMessageQueueAction, String>;

	@post
	public function postInject()
	{
		var redisHost :String = ServerConfig.REDIS_HOST;
		var redisPort :Int = ServerConfig.REDIS_PORT;
		//TODO share the redis connections
		//https://github.com/OptimalBits/bull/blob/master/PATTERNS.md#reusing-redis-connections
		this.cpu = new js.npm.bull.Bull.Queue(BullQueueNames.JobQueue, {redis:{port:redisPort, host:redisHost}});
		this.gpu = new js.npm.bull.Bull.Queue(BullQueueNames.JobQueueGpu, {redis:{port:redisPort, host:redisHost}});
		this.message = new js.npm.bull.Bull.Queue(BullQueueNames.SingleMessageQueue, {redis:{port:redisPort, host:redisHost}});

		QueueTools.addListeners(BullQueueNames.SingleMessageQueue, this.message);

		// Arbitrary, probably can be much higher
		var concurrentMessages = 10;
		// Weird JS thing, this wrap allows the bull client to see the message signature
		// (that is expects a "done" argument)
		function messageProcessor(job, done) {
			handlerMessage(job, done);
		}
		this.message.process(concurrentMessages, messageProcessor);

		injector.map(ccc.compute.server.services.queue.Queues).toValue(this);
	}

	public function enqueueJobCleanup(jobDef :DockerBatchComputeJob)
	{
		Assert.notNull(jobDef);
		var cleanupJob :BullQueueSingleMessageQueueAction = {
			type: BullQueueSingleMessageQueueType.jobRemoval,
			data: jobDef
		};

		var jobOpts :JobOptions = {
			attempts: 3,
			backoff: {
				type: 'fixed',
				//If this fails, try after 5 mins
				delay: Ms.parse('5m')
			},
			removeOnComplete: true,
			removeOnFail:true,
		}

		this.message.add(cleanupJob, jobOpts);
	}

	public function getQueue(params :JobParams) :Queue<QueueJobDefinition, QueueJobResults>
	{
		return params.gpu > 0 ? gpu : cpu;
	}

	function handlerMessage(job: Job<BullQueueSingleMessageQueueAction>, done :Done2<String>)
	{
		Assert.notNull(job);
		Assert.notNull(done);
		var action :BullQueueSingleMessageQueueAction = job.data;
		switch(action.type) {
			case log:
				logFromQueue(action.data, done);
			case jobRemoval:
				performJobRemoval(action.data, done);
		}
	}

	function logFromQueue(logBlob :BullQueueSingleMessageQueueActionLog, done :Done2<String>)
	{
		if (logBlob == null || logBlob.obj == null) {
			done(null, null);
			return;
		}
		// if (Reflect.field(logBlob.obj, 'm') == true) {
		// 	Metrics.log(logBlob.obj);
		// } else {
			switch(logBlob.level) {
				case 'debug': Log.debug(logBlob.obj);
				case 'info': Log.info(logBlob.obj);
				case 'warn': Log.warn(logBlob.obj);
				case 'error': Log.error(logBlob.obj);
				case 'critical': Log.critical(logBlob.obj);
				default: Log.warn({message: 'unhandled error blob from redis', logBlob:logBlob});
			}
		// }
		done(null, null);
	}

	function performJobRemoval(jobDef: DockerBatchComputeJob, done :Done2<String>)
	{
		Assert.notNull(jobDef);
		Assert.notNull(done);
		JobCommands.removeJob(injector, jobDef)
			.then(function(_) {
				Log.debug({jobId: jobDef.id, action:'cleaned out'});
				done(null, null);
			})
			.catchError(function(err) {
				Log.warn({error:err, 'message': 'Error on removeJob', jobId:jobDef.id});
				done(err, null);
			});
	}

	public function new() {}
}
