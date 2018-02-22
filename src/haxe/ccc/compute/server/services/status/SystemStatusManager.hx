package ccc.compute.server.services.status;

import ccc.WorkerStateRedis;

/**
 * Modify and listen to system updates
 */
@:build(t9.redis.RedisObject.build())
class SystemStatusManager
{
	static var PREFIX = '${CCC_PREFIX}status${SEP}';
	public static var REDIS_KEY_STATUS_JSON_STRING = '${PREFIX}key${SEP}system_status';

	/**
	 * Builds system status
	 */
	public static var SNIPPET_GET_STATUS =
	'
		local status = {workers={},queues={}, servers=0}
		local activeWorkerIds = redis.call("SMEMBERS", "${WorkerStateRedis.REDIS_MACHINES_ACTIVE}")
		for i,machineId in ipairs(activeWorkerIds) do
			${WorkerStateRedis.REDIS_SNIPPET_GET_SYSTEM_WORKERSTATE}
			--workerState object
			table.insert(status.workers, workerState)

			local jobs = {}

			local workerJobsKey = "${JobStatsTools.REDIS_KEY_ZSET_PREFIX_WORKER_JOBS}" ..machineId
			local jobs = redis.call("ZRANGE", workerJobsKey, 0, -1)
			workerState.jobs = jobs
			if jobs then
				for j,jobId in ipairs(jobs) do

				end
			end

			local workerJobsFinishedKey = "${JobStatsTools.REDIS_ZSET_JOBS_ACTIVE}" ..machineId
			local jobsFinished = redis.call("ZRANGE", workerJobsFinishedKey, 0, -1)
			workerState.finished = #jobsFinished
		end

		local activeJobIds = redis.call("ZRANGE", "${JobStatsTools.REDIS_ZSET_JOBS_ACTIVE}", 0, -1)
		status.jobs = activeJobIds
';

	@redis({lua:'
		${SNIPPET_GET_STATUS}
		return cjson.encode(status)
	'})
	static function getStatusInternal() :Promise<String> {}
	public static function getStatus(injector :Injector) :Promise<SystemStatus>
	{
		return getStatusInternal()
			.pipe(function(dataString) {
				if (dataString != null) {
					var statusBlob :SystemStatus = Json.parse(dataString);
					return QueueTools.getQueueSizes(injector)
						.then(function(jobQueues) {
							statusBlob.queues = jobQueues;
							if (t9.redis.RedisLuaTools.isArrayObjectEmpty(statusBlob.workers)) {
								statusBlob.workers = [];
							}
							if (t9.redis.RedisLuaTools.isArrayObjectEmpty(statusBlob.jobs)) {
								statusBlob.jobs = [];
							}
							for (worker in statusBlob.workers) {
								if (t9.redis.RedisLuaTools.isArrayObjectEmpty(worker.jobs)) {
									worker.jobs = [];
								}
							}
							return statusBlob;
						});
				} else {
					return Promise.promise(null);
				}
			});
	}

}
