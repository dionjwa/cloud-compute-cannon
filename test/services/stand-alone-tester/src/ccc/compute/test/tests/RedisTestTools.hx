package ccc.compute.test.tests;

import ccc.lambda.RedisLogGetter;

import js.Error;
import js.npm.redisdump.RedisDump;

using StringTools;

class RedisTestTools
{
	public static function isStringInRedis(redisAddress :String, query :String) :Promise<Bool>
	{
		return getRedisDump(redisAddress)
			.then(function(data) {
				return Json.stringify(data).indexOf(query) > -1;
			});
	}

	public static function getRedisDump(redisAddress :String) :Promise<Dynamic>
	{
		var promise = new DeferredPromise();
		RedisDump.dump({
			filter  : '*',
			port    : 6379,
			host    : redisAddress,
			format  : 'json',
			convert : null,
		}, function(err :Dynamic, data :Dynamic) {
			if (err != null) {
				promise.boundPromise.reject(err);
				return;
			}
			promise.resolve(Json.parse(data));
		});

		return promise.boundPromise;
	}

	public static function clearLogs() :Promise<Bool>
	{
	    return RedisLogGetter.getLogs()
	    	.thenTrue();
	}
}
