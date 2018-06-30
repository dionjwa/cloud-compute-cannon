package ccc.compute.server.services.queue;

import js.npm.bull.Bull;

/**
 * Manually add job to a bull queue
 *
 * Currently used to add redis logs statements to a bull
 * queue (rather than implementing a custom queue-like
 * thing for consuming and passing on redis logs)
 */

@:build(t9.redis.RedisObject.build())
class BullQueueJobTools
{
	//Expects
	// - queueName
	// - jobDataString
	// - jobOptString
	// - time
	//https://github.com/OptimalBits/bull/issues/153
	public static var SNIPPET_ADD_BULL_JOB =
	'
local prefix = "bull:" .. queueName .. ":"

local bullJobId = tostring(redis.call("INCR", prefix .. "id"))

local hashName = prefix .. bullJobId
redis.call("HMSET", hashName, "name", "__default__", "data", jobDataString, "opts", jobOptString, "progress", 0, "timestamp", time, "delay", "0", "priority", "0")

if redis.call("EXISTS", prefix .. "meta-paused") ~= 1 then
	redis.call("LPUSH", prefix .. "wait", bullJobId)
else
	redis.call("RPUSH", prefix .. "paused", bullJobId)
end
redis.call("PUBLISH", prefix .. "waiting@", bullJobId)
	';

	/**
	 * This function is mostly just to functionally test the relevant
	 * SNIPPET_ADD_BULL_JOB that is used elsewhere in other lua scripts.
	 */
	@redis({lua:'
		local queueName = ARGV[1]
		local jobDataString = ARGV[2]
		local jobOptString = ARGV[3]
		local customBullJobId = ARGV[4]
		local time = ARGV[5]
		${SNIPPET_ADD_BULL_JOB}
		return bullJobId
	'})
	static function addBullJobInsideRedisInternal(queue :BullQueueNames, job :String, jobOpts :String, bullJobId :String, time :Float) :Promise<String> {}
	public static function addBullJobInsideRedis(queue :BullQueueNames, job :Dynamic, jobOpts :JobOptions, bullJobId :String) :Promise<String>
	{
		Assert.notNull(queue);
		Assert.notNull(job);
		return addBullJobInsideRedisInternal(
				queue,
				Json.stringify(job),
				jobOpts != null ? Json.stringify(jobOpts): '{}',
				bullJobId,
				Date.now().getTime());
	}
}
