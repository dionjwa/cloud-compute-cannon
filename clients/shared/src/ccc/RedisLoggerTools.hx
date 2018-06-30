package ccc;

import ccc.Constants.*;
import ccc.SharedConstants.*;

import haxe.Json;

import js.Error;
import js.npm.redis.RedisClient;

class RedisLoggerTools
{
	inline static var PREFIX = '${CCC_PREFIX}logs${SEP}';

	inline public static var REDIS_KEY_LOGS_LIST = '${PREFIX}list';
	inline public static var REDIS_KEY_LOGS_CHANNEL = '${PREFIX}channel';

	inline public static var REDIS_LOG_DEBUG = 'debug';
	inline public static var REDIS_LOG_INFO = 'info';
	inline public static var REDIS_LOG_WARN = 'warn';
	inline public static var REDIS_LOG_ERROR = 'error';
	/**
	 * Expects in lua:
	 *    logMessage
	 */
	public static var SNIPPET_REDIS_LOG = '
		local queueName = "${BullQueueNames.SingleMessageQueue}"
		local jobOptString = cjson.encode({removeOnComplete=true,removeOnFail=true,attempts=2})
		local jobDataString = cjson.encode({type="${BullQueueSingleMessageQueueType.log}", data=logMessage})
		${ccc.compute.server.services.queue.BullQueueJobTools.SNIPPET_ADD_BULL_JOB}
	';

	static function logToRedis(redis :RedisClient, level :String, logThing :Dynamic, ?disableTrace: Bool = false, pos :haxe.PosInfos)
	{
		var obj :haxe.DynamicAccess<Dynamic> = switch(untyped __typeof__(logThing)) {
			case 'object': cast Reflect.copy(logThing);
			default: cast {message:Std.string(logThing)};
		}
		if (pos != null) {
			obj['src'] = {file:pos.fileName, line:pos.lineNumber, func:'${pos.className.split(".").pop()}.${pos.methodName}'};
		}
		obj.set('level', level);
		obj.set('time', Date.now().getTime());
		var logString = Json.stringify(obj);
		redis.rpush(REDIS_KEY_LOGS_LIST, logString, function(err, result) {
			if (err != null) {
				trace(err);
			}
		});
		if (!disableTrace) {
			trace(logString);
		}
	}

	public static function debugLog(redis :RedisClient, obj :Dynamic, ?disableTrace: Bool = false, ?pos :haxe.PosInfos)
	{
		logToRedis(redis, REDIS_LOG_DEBUG, obj, disableTrace, pos);
	}

	public static function infoLog(redis :RedisClient, obj :Dynamic, ?disableTrace: Bool = false, ?pos :haxe.PosInfos)
	{
		logToRedis(redis, REDIS_LOG_INFO, obj, disableTrace, pos);
	}

	public static function errorLog(redis :RedisClient, obj :Dynamic, ?disableTrace: Bool = false, ?pos :haxe.PosInfos)
	{
		logToRedis(redis, REDIS_LOG_ERROR, obj, disableTrace, pos);
	}

	public static function errorEventLog(redis :RedisClient, err :Error, ?message :String, ?pos :haxe.PosInfos)
	{
		var errObj = {
			errorJson: try{Json.stringify(err);} catch(e :Dynamic) {null;},
			stack: try{err.stack;} catch(e :Dynamic) {null;},
			errorMessage: try{err.message;} catch(e :Dynamic) {null;},
			message: message
		};
		logToRedis(redis, REDIS_LOG_ERROR, errObj, false, pos);
	}
}