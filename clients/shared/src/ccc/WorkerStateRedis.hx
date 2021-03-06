package ccc;

import haxe.Json;

import js.npm.redis.RedisClient;

import promhx.Promise;
import promhx.RedisPromises;

import ccc.Constants.*;
import ccc.SharedConstants.*;

using StringTools;

@:build(t9.redis.RedisObject.build())
class WorkerStateRedis
{
	static var PREFIX = '${CCC_PREFIX}worker${SEP}';
	static var REDIS_MACHINE_DOCKER_INFO = '${PREFIX}hash${SEP}dockerinfo';//<MachineId, DockerInfo>
	static var REDIS_MACHINE_STARTS = '${PREFIX}hash${SEP}starts';//<MachineId, DockerInfo>
	public static var REDIS_MACHINES_ACTIVE = '${PREFIX}set${SEP}active';
	public static var REDIS_MACHINES_GPU = '${PREFIX}set${SEP}gpu';//<MachineId>
	static var REDIS_MACHINE_LAST_HEALTH_STATUS = '${PREFIX}hash${SEP}status_health';//<MachineId, WorkerHealthStatus>
	static var REDIS_MACHINE_LAST_STATUS_TIME = '${PREFIX}hash${SEP}status_time';//<MachineId, Float>
	public static var REDIS_MACHINE_DISK = '${PREFIX}hash${SEP}disk';//<MachineId, Float>
	static var REDIS_MACHINE_EVENT_LIST = '${PREFIX}hash${SEP}events';//<MachineId, JSON>
	public static var REDIS_MACHINE_CHANNEL_PREFIX = '${PREFIX}channel${SEP}';
	public static var REDIS_MACHINE_UPDATED_CHANNEL = '${PREFIX}channel';

	/**
	 * Expects:
	 * 	machineId
	 */
	public static var REDIS_SNIPPET_GET_SYSTEM_WORKERSTATE = '

	local workerState
	if redis.call("HEXISTS", "${REDIS_MACHINE_DOCKER_INFO}", machineId) == 0 then
		workerState = nil
	else
		local starts = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_STARTS}", machineId))
		local dockerInfo = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_DOCKER_INFO}", machineId))
		local status = redis.call("HGET", "${REDIS_MACHINE_LAST_STATUS}", machineId)
		local statusHealth = redis.call("HGET", "${REDIS_MACHINE_LAST_HEALTH_STATUS}", machineId)
		local statusTime = redis.call("HGET", "${REDIS_MACHINE_LAST_STATUS_TIME}", machineId)
		if statusTime then
			statusTime = tonumber(statusTime)
		end
		local gpu = 0
		if redis.call("SISMEMBER", "${REDIS_MACHINES_GPU}", machineId) == 1 then
			gpu = 1
		end
		local events = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_EVENT_LIST}", machineId))
		local diskUsage = tonumber(redis.call("HGET", "${REDIS_MACHINE_DISK}", machineId))
		local lastJobTime = redis.call("HGET", "${REDIS_MACHINE_LAST_STATUS_TIME}", machineId)
		if lastJobTime then
			lastJobTime = tonumber(lastJobTime)
		end
		workerState = {id=machineId, lastJobTime=lastJobTime, starts=starts, cpus=dockerInfo.NCPU, status=status, gpus=gpu, disk=diskUsage}
	end
	';

	static var REDIS_SNIPPET_GET_WORKERSTATE = '

	local workerState
	if redis.call("HEXISTS", "${REDIS_MACHINE_DOCKER_INFO}", machineId) == 0 then
		workerState = nil
	else
		local starts = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_STARTS}", machineId))
		local dockerInfo = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_DOCKER_INFO}", machineId))
		local status = redis.call("HGET", "${REDIS_MACHINE_LAST_STATUS}", machineId)
		local statusHealth = redis.call("HGET", "${REDIS_MACHINE_LAST_HEALTH_STATUS}", machineId)
		local statusTime = redis.call("HGET", "${REDIS_MACHINE_LAST_STATUS_TIME}", machineId)
		if statusTime then
			statusTime = tonumber(statusTime)
		end
		local gpu = false
		if redis.call("SISMEMBER", "${REDIS_MACHINES_GPU}", machineId) then
			gpu = true
		end
		local events = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_EVENT_LIST}", machineId))
		workerState = {id=machineId, starts=starts, DockerInfo=dockerInfo, status=status, statusHealth=statusHealth, statusTime=statusTime, events=events, gpu=gpu}
	end
	';

	//-- ${REDIS_SNIPPET_GET_WORKERSTATE}
	static var REDIS_PUBLISH_WORKER_STATE = '
	-- redis.log(redis.LOG_WARNING, "reason=" .. tostring(reason))
	redis.call("PUBLISH", "${REDIS_MACHINE_CHANNEL_PREFIX}" .. machineId, reason)
	redis.call("PUBLISH", "${REDIS_MACHINE_UPDATED_CHANNEL}", machineId)
	';

	static var SCRIPT_INITIALIZE_WORKER = '
	local machineId = ARGV[1]
	local dockerInfo = cjson.decode(ARGV[2])
	local gpu = ARGV[3]
	redis.log(redis.LOG_WARNING, "Init worker gpu= " .. tostring(gpu))
	local timeString = ARGV[4]
	local time = tonumber(timeString)
	local exists = redis.call("HEXISTS", "${REDIS_MACHINE_DOCKER_INFO}", machineId)
	if exists == 0 or exists == "0" then
		redis.call("HSET", "${REDIS_MACHINE_DOCKER_INFO}", machineId, cmsgpack.pack(dockerInfo))
		redis.call("HSET", "${REDIS_MACHINE_STARTS}", machineId, cmsgpack.pack({}))
		redis.call("HSET", "${REDIS_MACHINE_EVENT_LIST}", machineId, cmsgpack.pack({}))
		if gpu and gpu ~= "" and tonumber(gpu) > 0 then
			redis.call("SADD", "${REDIS_MACHINES_GPU}", machineId)
		else
			redis.call("SREM", "${REDIS_MACHINES_GPU}", machineId)
		end
		--Assume that the first init the machine is healthy
		redis.call("HSET", "${REDIS_MACHINE_LAST_STATUS}", machineId, "${WorkerStatus.OK}")

		local key = "${REDIS_KEY_PREFIX_WORKER_HEALTH_STATUS}" .. machineId
		redis.call("SETEX", key, ${WORKER_STATUS_KEY_TTL_SECONDS}, "${WorkerHealthStatus.OK}")
		redis.call("HSET", "${REDIS_MACHINE_LAST_STATUS_TIME}", machineId, timeString)
		redis.call("HSET", "${REDIS_MACHINE_LAST_HEALTH_STATUS}", machineId, "${WorkerHealthStatus.OK}")

		local logMessage = {${LogKeys.workerevent}="${WorkerEventType.INIT}", machineId=machineId, time=time, level="${RedisLoggerTools.REDIS_LOG_INFO}"}
		${RedisLoggerTools.SNIPPET_REDIS_LOG}
	end
	local starts = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_STARTS}", machineId))
	table.insert(starts, time)
	redis.call("HSET", "${REDIS_MACHINE_STARTS}", machineId, cmsgpack.pack(starts))

	local events = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_EVENT_LIST}", machineId))
	table.insert(events, {t=time, e="${WorkerEventType.START}"})
	redis.call("HSET", "${REDIS_MACHINE_EVENT_LIST}", machineId, cmsgpack.pack(events))

	redis.call("SADD", "${REDIS_MACHINES_ACTIVE}", machineId)

	local reason = "${WorkerUpdateCommand.UpdateReasonInitializing}"
	-- redis.log(redis.LOG_WARNING, "Publishing state due to " .. reason)
	${REDIS_PUBLISH_WORKER_STATE}

	local logMessage = {${LogKeys.workerevent}="${WorkerEventType.START}", machineId=machineId, time=time, level="${RedisLoggerTools.REDIS_LOG_INFO}"}
	${RedisLoggerTools.SNIPPET_REDIS_LOG}
	';
	@redis({lua:'${SCRIPT_INITIALIZE_WORKER}'})
	public static function initializeWorkerInternal(id :MachineId, dockerInfoString :String, gpu :String, now :Float) :Promise<Bool> {}
	public static function initializeWorker(id :MachineId, dockerInfo :DockerInfo, gpu :String) :Promise<Bool>
	{
		return initializeWorkerInternal(id, Json.stringify(dockerInfo), gpu, time());
	}

	@redis({
		lua:'
			local machineId = ARGV[1]
			${REDIS_SNIPPET_GET_WORKERSTATE}
			if workerState then
				return cjson.encode(workerState)
			else
				return
			end
		'
	})
	public static function getInternal(id :MachineId) :Promise<String> {}
	public static function get(id :MachineId) :Promise<WorkerState>
	{
		return getInternal(id)
			.then(function(blob) {
				if (blob == null) {
					return null;
				}
				return Json.parse(blob);
			});
	}

	public static function getWorkerStateNotificationKey(id :MachineId) :String
	{
		return '${REDIS_MACHINE_CHANNEL_PREFIX}${id}';
	}

	public static function getAllWorkers() :Promise<Array<MachineId>>
	{
		return cast RedisPromises.hkeys(REDIS_CLIENT, REDIS_MACHINE_DOCKER_INFO);
	}

	public static function getAllActiveWorkers() :Promise<Array<MachineId>>
	{
		return cast RedisPromises.smembers(REDIS_CLIENT, REDIS_MACHINES_ACTIVE);
	}

	static var SET_HEALTH_STATUS_SCRIPT =
	'
	local machineId = ARGV[1]
	local statusHealth = ARGV[2]
	local timeString = ARGV[3]
	local time = tonumber(timeString)

	if redis.call("HGET", "${REDIS_MACHINE_LAST_STATUS}", machineId) == "${WorkerStatus.REMOVED}" then
		return
	end

	local key = "${REDIS_KEY_PREFIX_WORKER_HEALTH_STATUS}" .. machineId

	local reason = nil
	if redis.call("HGET", "${REDIS_MACHINE_LAST_HEALTH_STATUS}", machineId) == statusHealth then
		redis.call("SETEX", key, ${WORKER_STATUS_KEY_TTL_SECONDS}, statusHealth)
		redis.call("HSET", "${REDIS_MACHINE_LAST_STATUS_TIME}", machineId, timeString)
		reason = "${WorkerUpdateCommand.HealthCheckPerformed}"
	else
		if statusHealth == "${WorkerHealthStatus.OK}" then
			--If we go from not OK to OK, then record that event
			if redis.call("HGET", "${REDIS_MACHINE_LAST_STATUS}", machineId) == "${WorkerStatus.UNHEALTHY}" then
				local events = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_EVENT_LIST}", machineId))
				table.insert(events, {t=time, e="${WorkerEventType.HEALTHY}"})
				redis.call("HSET", "${REDIS_MACHINE_EVENT_LIST}", machineId, cmsgpack.pack(events))

				redis.call("SETEX", key, ${WORKER_STATUS_KEY_TTL_SECONDS}, "${WorkerStatus.OK}")

				redis.call("HSET", "${REDIS_MACHINE_LAST_STATUS}", machineId, "${WorkerStatus.OK}")
				redis.call("HSET", "${REDIS_MACHINE_LAST_HEALTH_STATUS}", machineId, statusHealth)
				redis.call("HSET", "${REDIS_MACHINE_LAST_STATUS_TIME}", machineId, timeString)
				reason = "${WorkerUpdateCommand.UpdateReasonToHealthy}"
			end
		elseif string.sub(statusHealth,1,string.len("BAD")) == "BAD" then
			if redis.call("HGET", "${REDIS_MACHINE_LAST_STATUS}", machineId) == "${WorkerStatus.OK}" then
				local events = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_EVENT_LIST}", machineId))
				table.insert(events, {t=time, e="${WorkerEventType.UNHEALTHY}", data=statusHealth})
				redis.call("HSET", "${REDIS_MACHINE_EVENT_LIST}", machineId, cmsgpack.pack(events))

				redis.call("HSET", "${REDIS_MACHINE_LAST_STATUS}", machineId, "${WorkerStatus.UNHEALTHY}")
				redis.call("SETEX", key, ${WORKER_STATUS_KEY_TTL_SECONDS}, statusHealth)
				redis.call("HSET", "${REDIS_MACHINE_LAST_HEALTH_STATUS}", machineId, statusHealth)
				redis.call("HSET", "${REDIS_MACHINE_LAST_STATUS_TIME}", machineId, timeString)
				reason = "${WorkerUpdateCommand.UpdateReasonToUnHealthy}"
			end
		end
	end
	if reason then
		-- redis.log(redis.LOG_WARNING, "Publishing state due to " .. reason)
		${REDIS_PUBLISH_WORKER_STATE}
	end
	';
	@redis({
		lua:'${SET_HEALTH_STATUS_SCRIPT}'
	})
	static function setHealthStatusInternal(machineId :MachineId, status :WorkerHealthStatus, time :Float) :Promise<Bool> {}
	public static function setHealthStatus(machineId :MachineId, status :WorkerHealthStatus) :Promise<Bool>
	{
		return setHealthStatusInternal(machineId, status, Date.now().getTime());
	}

	public static function getHealthStatus(machineId :MachineId) :Promise<WorkerHealthStatus>
	{
		return RedisPromises.hget(REDIS_CLIENT, REDIS_MACHINE_LAST_HEALTH_STATUS, machineId)
			.then(function(s :String) {
				var status :WorkerHealthStatus = s;
				if (s == null) {
					status = WorkerHealthStatus.NULL;
				}
				return status;
			});
	}

	public static function getStatus(machineId :MachineId) :Promise<WorkerStatus>
	{
		return RedisPromises.hget(REDIS_CLIENT, REDIS_MACHINE_LAST_STATUS, machineId)
			.then(function(s :String) {
				var status :WorkerStatus = s;
				return status;
			});
	}


	// static var SCRIPT_GET_START_TIME = '
	// local machineId = ARGV[1]
	// local starts = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_STARTS}", machineId))
	// return starts[1]
	// ';
	// public static function getStartTime(redis :RedisClient, machineId :MachineId) :Promise<Dynamic>
	// {
	// 	var promise = new promhx.CallbackPromise();
	// 	redis.eval([
	// 		SCRIPT_GET_START_TIME,
	// 		0,
	// 		machineId
	// 	], promise.cb2);
	// 	return cast promise
	// 		.then(function(s :String) {
	// 			return Std.parseFloat(s);
	// 		});
	// }

	static var TERMINATE_SCRIPT =
	'
	local machineId = ARGV[1]
	local timeString = ARGV[2]
	local time = tonumber(timeString)
	redis.call("SREM", "${REDIS_MACHINES_ACTIVE}", machineId)

	if redis.call("HEXISTS", "${REDIS_MACHINE_LAST_STATUS}", machineId) == 1 and redis.call("HGET", "${REDIS_MACHINE_LAST_STATUS}", machineId) ~= "${WorkerStatus.REMOVED}" then
		local events = cmsgpack.unpack(redis.call("HGET", "${REDIS_MACHINE_EVENT_LIST}", machineId))
		table.insert(events, {t=time, e="${WorkerEventType.TERMINATE}"})
		redis.call("HSET", "${REDIS_MACHINE_EVENT_LIST}", machineId, cmsgpack.pack(events))
		redis.call("HSET", "${REDIS_MACHINE_LAST_STATUS}", machineId, "${WorkerStatus.REMOVED}")
		redis.call("HSET", "${REDIS_MACHINE_LAST_STATUS_TIME}", machineId, timeString)
		local key = "${REDIS_KEY_PREFIX_WORKER_HEALTH_STATUS}" .. machineId
		redis.call("DEL", key)

		local reason = "${WorkerUpdateCommand.UpdateReasonTermination}"
		-- redis.log(redis.LOG_WARNING, "Publishing state due to " .. reason)
		${REDIS_PUBLISH_WORKER_STATE}
	end
	';
	public static function terminate(redis :RedisClient, machineId :MachineId) :Promise<Dynamic>
	{
		var promise = new promhx.CallbackPromise();
		redis.eval([
			TERMINATE_SCRIPT,
			0,
			machineId,
			Date.now().getTime()
		], promise.cb2);
		return cast promise;
	}

	public static function getWorkerHealthStatuses(machineId :MachineId, status :WorkerHealthStatus) :Promise<TypedDynamicObject<MachineId, WorkerHealthStatus>>
	{
		var redis :RedisClient = REDIS_CLIENT;
		return RedisPromises.keys(redis, '${REDIS_KEY_PREFIX_WORKER_HEALTH_STATUS}*')
			.pipe(function(workers :Array<MachineId>) {
				var result :TypedDynamicObject<MachineId, WorkerHealthStatus> = {};
				var promises :Array<Promise<Bool>> = workers.map(function(instanceHealthKey) {
					return RedisPromises.get(redis, instanceHealthKey)
						.then(function(val) {
							result.set(instanceHealthKey.replace(REDIS_KEY_PREFIX_WORKER_HEALTH_STATUS, ''), val);
							return true;
						});
				});
				return Promise.whenAll(promises)
					.then(function(_) {
						return result;
					});
			});
	}

	public static function setDiskUsage(machineId :MachineId, disk :Float) :Promise<Int>
	{
		return RedisPromises.hset(REDIS_CLIENT, REDIS_MACHINE_DISK, machineId, Std.string(disk));
	}

	//Expects local isPaused
	static var SNIPPET_SEND_COMMAND_TO_ALL_WORKERS =
	'
	local reason = ARGV[1]
	-- redis.log(redis.LOG_WARNING, "command=" .. tostring(reason))

	local activeWorkerIds = redis.call("SMEMBERS", "${REDIS_MACHINES_ACTIVE}")
	for i,machineId in ipairs(activeWorkerIds) do
		${REDIS_PUBLISH_WORKER_STATE}
	end

	return cjson.encode(activeWorkerIds)

	';
	@redis({
		lua:'${SNIPPET_SEND_COMMAND_TO_ALL_WORKERS}'
	})
	public static function sendCommandToAllWorkers(command :WorkerUpdateCommand) :Promise<String> {}

	inline static function time() :Float
	{
		return Date.now().getTime();
	}

}