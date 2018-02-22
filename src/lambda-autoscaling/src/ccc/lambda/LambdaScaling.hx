package ccc.lambda;

using ccc.RedisLoggerTools;
using ccc.compute.shared.LogEvents;

typedef ScaleResult = {
	scaleUp:Bool,
	scaleDown:Bool,
	cleanup:Bool
}

typedef ScaleResults = {
	cpu:ScaleResult,
	gpu:ScaleResult
}

class LambdaScaling
{
	var redis :RedisClient;
	static var REDIS_KEY_LAST_SCALE_DOWN_TIME = 'ccc::last-scale-down-time';
	static var REDIS_KEY_LAST_SCALE_DOWN_TIME_GPU = 'ccc::last-scale-down-time-gpu';

	static function getRedisClient(opts :RedisOptions) :Promise<RedisClient>
	{
		var redisParams = {
			port: opts.port,
			host: opts.host
		}
		var client = Redis.createClient(opts);
		var promise = new DeferredPromise();
		client.once(RedisEvent.Connect, function() {
			trace({event:RedisEvent.Connect, redisParams:redisParams});
			//Only resolve once connected
			if (!promise.boundPromise.isResolved()) {
				promise.resolve(client);
			} else {
				trace({log:'Got redis connection, but our promise is already resolved ${redisParams.host}:${redisParams.port}'});
			}
		});
		client.on(RedisEvent.Error, function(err) {
			if (!promise.boundPromise.isResolved()) {
				client.end(true);
				promise.boundPromise.reject(err);
			} else {
				trace({event:'redis.${RedisEvent.Error}', error:err});
			}
		});
		client.on(RedisEvent.Reconnecting, function(msg) {
			trace({event:'redis.${RedisEvent.Reconnecting}', delay:msg.delay, attempt:msg.attempt});
		});
		client.on(RedisEvent.End, function() {
			trace({event:RedisEvent.End, redisParams:redisParams});
		});

		client.on(RedisEvent.Warning, function(warningMessage) {
			trace({event:'redis.${RedisEvent.Warning}', warning:warningMessage});
		});

		return promise.boundPromise;
	}

	public static function getRedis(redisHost :String)
	{
		return Redis.createClient({host:redisHost, port:6379});
	}

	public function setRedis(r :RedisClient)
	{
		this.redis = r;
		return this;
	}

	public function new() {}

	public function traceJson<A>() :A->Promise<A>
	{
		return function(a :A) {
			return getJson()
				.then(function(blob) {
					trace(Json.stringify(blob, null, '  '));
					return a;
				});
		}
	}

	public function getJson() :Promise<Dynamic>
	{
		return getAllInstanceIds()
			.pipe(function(instanceIds :Array<MachineId>) {
				return RedisPromises.smembers(redis, WorkerStateRedis.REDIS_MACHINES_ACTIVE)
					.pipe(function(dbMembersRedis) {
						var dbMembers :Array<MachineId> = cast dbMembersRedis;
						var workerStatus :Array<{id:MachineId,status:String,alive:String}> = [];
						var result = {
							workerIds:instanceIds,
							workerIdsInDatabase:dbMembers,
							workerStatus: workerStatus
						}

						var duplicatedMembers :Array<String> = instanceIds.concat(dbMembers);
						var allMembers :Array<String> = ArrayTools.removeDuplicates(duplicatedMembers);

						trace('instanceIds=${instanceIds}');
						trace('dbMembers=${dbMembers}');
						trace('allMembers=${allMembers}');
						return Promise.whenAll(allMembers.map(function(id) {
							return getInstancesHealthStatus(id)
								.pipe(function(status) {
									return getTimeSinceInstanceStarted(id)
										.then(function(duration) {
											workerStatus.push({
												id: id,
												status: status,
												alive: DateFormatTools.getShortStringOfDuration(duration)
											});
										});
								});
						}))
						.then(function(_) {
							return result;
						});
					});
			});
	}

	public function checks() :Promise<Bool>
	{
		return preChecks()
			.pipe(function(_) {
				return postChecks();
			});
	}

	public function preChecks() :Promise<Bool>
	{
		return updateActiveWorkerIdsInRedis();
	}

	public function postChecks() :Promise<Bool>
	{
		return Promise.promise(true)
			.pipe(function(_) {
				return removeUnhealthyWorkers(AsgType.CPU);
			})
			.pipe(function(_) {
				return removeUnhealthyWorkers(AsgType.GPU);
			})
			.pipe(function(_) {
				return removeWorkersInActiveSetThatAreNotRunning();
			});
	}

	public function scale() :Promise<ScaleResults>
	{
		return Promise.promise(true)
			.pipe(function(_) {
				return preChecks();
			})
			.pipe(function(_) {

				function scaleInternal(type :AsgType) {
					return scaleUp(type)
						.pipe(function(wasScaleUpAction) {
							var result :ScaleResult = {
								scaleUp: wasScaleUpAction,
								scaleDown: false,
								cleanup: false
							}
							if (wasScaleUpAction) {
								//Don't scale down if there was a scale up
								return Promise.promise(result);
							} else {
								//Check the last time a scale down action occured
								return getLastScaleDownTime(type)
									.pipe(function(lastScaleDownTime) {
										var now = Date.now().getTime();
										var doScaleDown = lastScaleDownTime == null
											|| (now - lastScaleDownTime) >= (15*60*1000);
										if (doScaleDown) {
											trace('type=$type Scaling down bc now=$now lastScaleDownTime=$lastScaleDownTime diff=${now - lastScaleDownTime}');
											return scaleDown(type);
										} else {
											trace('type=$type NOT Scaling down bc now=$now lastScaleDownTime=$lastScaleDownTime diff=${now - lastScaleDownTime}');
											return Promise.promise(false);
										}
									})
									.pipe(function(didDownScale) {
										result.scaleDown = didDownScale;
										return setLastScaleDownTime(type)
											.then(function(_) {
												return result;
											});
									});
							}
						});
				}

				return Promise.whenAll([
					scaleInternal(AsgType.CPU),
					scaleInternal(AsgType.GPU),
				])
				.then(function(scaleResults) {
					return {
						cpu: scaleResults[0],
						gpu: scaleResults[1],
					};
				});
			})
			.pipe(function(scaleResults) {
				if (scaleResults.cpu.scaleUp || scaleResults.cpu.scaleDown || scaleResults.gpu.scaleUp || scaleResults.gpu.scaleDown) {
					return Promise.promise(scaleResults);
				} else {
					return Promise.promise(true)
						.pipe(function(_) {
							return postChecks();
						})
						.then(function(_) {
							scaleResults.cpu.cleanup = true;
							scaleResults.gpu.cleanup = true;
							return scaleResults;
						});
				}
			});
	}

	public function scaleDown(type :AsgType) :Promise<Bool>
	{
		return Promise.promise(true)
			.pipe(function(_) {
				return getQueueSize(type);
			})
			.pipe(function(queueLength) {
				redis.debugLog({queueLength:queueLength});
				if (queueLength == 0) {
					return getMinMaxDesired(type)
						.pipe(function(minMax) {
							redis.debugLog({minMax:minMax});
							var NewDesiredCapacity = minMax.MinSize;

							if (minMax.DesiredCapacity - NewDesiredCapacity > 0) {
								redis.infoLog({
									op: 'ScaleDown',
									current: minMax,
									queueLength: queueLength,
									NewDesiredCapacity: NewDesiredCapacity,
									instancesToKill: minMax.DesiredCapacity - NewDesiredCapacity
								}.add(LogEventType.WorkersDesiredCapacity));
								return setDesiredCapacity(type, NewDesiredCapacity)
									.pipe(function(resultStatememt) {
										redis.infoLog(resultStatememt);
										return Promise.promise(true);
									});
							} else {
								return Promise.promise(false);
							}
						});
				} else {
					return Promise.promise(false);
				}
			});
	}

	public function scaleUp(type :AsgType) :Promise<Bool>
	{
		return Promise.promise(true)
			.pipe(function(_) {
				return getQueueSize(type);
			})
			.pipe(function(queueLength) {
				trace('scaleUp ok getQueueSize=$queueLength');
				redis.infoLog({queueLength:queueLength});
				if (queueLength > 0) {
					return getMinMaxDesired(type)
						.pipe(function(minMax) {
							// "MinSize": 2,
							// "MaxSize": 4,
							// "DesiredCapacity": 2,
							// "DefaultCooldown": 60,
							//This logic could probably be tweaked
							//If we have at least one in the queue, increase
							//the DesiredCapacity++
							redis.debugLog({
								op: 'ScaleUp',
								MinSize: minMax.MinSize,
								MaxSize: minMax.MaxSize,
								DesiredCapacity: minMax.DesiredCapacity,
								queueLength: queueLength
							});


							var currentDesiredCapacity = minMax.DesiredCapacity;
							var newDesiredCapacity = currentDesiredCapacity + 1;
							redis.infoLog({newDesiredCapacity:newDesiredCapacity});
							if (newDesiredCapacity <= minMax.MaxSize && minMax.DesiredCapacity < minMax.MaxSize) {
								return setDesiredCapacity(type, newDesiredCapacity)
									.pipe(function(resultStatememt) {
										trace(resultStatememt);
										return Promise.promise(true);
									});
							} else {
								return Promise.promise(false);
							}
						});
				} else {
					return Promise.promise(false);
				}
			});
	}

	public function terminateWorker(id :MachineId) :Promise<Bool>
	{
		traceYellow('terminateWorker=$id');
		return WorkerStateRedis.terminate(redis, id)
			.thenTrue();
	}

	public function setDesiredCapacity(type :AsgType, workerCount :Int) :Promise<String>
	{
		throw 'override setDesiredCapacity';
		return Promise.promise('override');
	}

	function getLastScaleDownTime(type :AsgType) :Promise<Float>
	{
		var key = type == AsgType.GPU ? REDIS_KEY_LAST_SCALE_DOWN_TIME_GPU : REDIS_KEY_LAST_SCALE_DOWN_TIME;
		return RedisPromises.get(redis, key)
			.then(function(timeString) {
				return timeString != null ? Std.parseFloat(timeString) : null;
			});
	}

	function setLastScaleDownTime(type :AsgType) :Promise<Bool>
	{
		var key = type == AsgType.GPU ? REDIS_KEY_LAST_SCALE_DOWN_TIME_GPU : REDIS_KEY_LAST_SCALE_DOWN_TIME;
		return RedisPromises.set(redis, key, '${Date.now().getTime()}');
	}

	function updateActiveWorkerIdsInRedis() :Promise<Bool>
	{
		return getAllInstanceIds()
			.pipe(function(instanceIds) {
				var promise = new promhx.deferred.DeferredPromise();
				var commands :Array<Array<String>> = [];
				commands.push(['del', WorkerStateRedis.REDIS_MACHINES_ACTIVE]);
				for (id in instanceIds) {
					commands.push(['sadd', WorkerStateRedis.REDIS_MACHINES_ACTIVE, id]);
				}
				redis.multi(commands).exec(function(err, result) {
					if (err != null) {
						promise.boundPromise.reject(err);
						return;
					}
					promise.resolve(true);
				});
				return promise.boundPromise;
			})
			.thenTrue();
	}

	function removeWorkersInActiveSetThatAreNotRunning() :Promise<Bool>
	{
		return getAllInstanceIds()
			.pipe(function(instanceIds) {
				return RedisPromises.smembers(redis, WorkerStateRedis.REDIS_MACHINES_ACTIVE)
					.pipe(function(dbMembers) {
						var promises = [];
						for (dbInstanceId in dbMembers) {
							if (!instanceIds.has(dbInstanceId)) {
								redis.debugLog({message:'$dbInstanceId not running, removing from active set'});
								promises.push(RedisPromises.srem(redis, WorkerStateRedis.REDIS_MACHINES_ACTIVE, dbInstanceId));
							}
						}
						return Promise.whenAll(promises)
							.thenTrue();
					});
			});
	}

	/**
	 * Returns the actual ids of workers removed
	 * since you cannot remove workers with jobs
	 * running
	 * @param  maxWorkersToRemove :Int          [description]
	 * @return                    [description]
	 */
	public function removeIdleWorkers(type :AsgType, maxWorkersToRemove :Int) :Promise<Array<String>>
	{
		throw 'override removeIdleWorkers';
		return Promise.promise([]);
	}

	function getMinMaxDesired(type :AsgType) :Promise<MinMaxDesired>
	{
		throw 'override getMinMaxDesired';
		return Promise.promise(null);
	}

	function removeUnhealthyWorkers(type :AsgType) :Promise<Bool>
	{
		redis.infoLog('removeUnhealthyWorkers');
		return getInstanceIds(type)
			.pipe(function(instanceIds) {
				trace('instanceIds=$instanceIds');
				var promises = instanceIds.map(function(instanceId) {
					return isInstanceHealthy(instanceId)
						.pipe(function(isHealthy) {
							trace('instanceId=$instanceId isHealthy=$isHealthy');
							if (!isHealthy) {
								//Double check, if the instance just started, it may not have had time
								//to initialize
								return getTimeSinceInstanceStarted(instanceId)
									.pipe(function(timeMilliseconds) {
										var timeSeconds = timeMilliseconds / 1000;
										if (timeSeconds < 600) {//10mins
											redis.debugLog({instanceId:instanceId, message:'Not terminating potentially sick worker since it just stared up $instanceId'});
											return Promise.promise(true);
										} else {
											redis.infoLog(LogFieldUtil.addWorkerEvent({instanceId:instanceId, message:'Terminating ${instanceId}'}, WorkerEventType.TERMINATE));
											return terminateWorker(instanceId)
												.errorPipe(function(err) {
													redis.errorLog({error:err});
													return Promise.promise(true);
												})
												.then(function(_) {
													return true;
												});
										}
									});
							} else {
								return Promise.promise(true);
							}
						});
				});
				return Promise.whenAll(promises)
					.then(function(ignored) {
						return true;
					});
			})
			.then(function(ignored) {
				return true;
			});
	}

	function getQueueSizeAll() :Promise<Int>
	{
		return getQueueSize(AsgType.CPU)
			.pipe(function(sizeCpu) {
				return getQueueSize(AsgType.GPU)
					.then(function(sizeGpu) {
						return sizeCpu + sizeGpu;
					});
			});
	}

	function getQueueSize(type :AsgType) :Promise<Int>
	{
		var promise = new DeferredPromise();
		var key = switch(type) {
			case CPU: 'bull:${BullQueueNames.JobQueue}:wait';
			case GPU: 'bull:${BullQueueNames.JobQueueGpu}:wait';
		};
		redis.llen(key, function(err, length) {
			if (err != null) {
				promise.boundPromise.reject(err);
			} else {
				promise.resolve(length);
			}
		});
		return promise.boundPromise;
	}

	function getJobCount(instanceId :MachineId) :Promise<Int>
	{
		var promise = new DeferredPromise();
		redis.zcard('${REDIS_KEY_ZSET_PREFIX_WORKER_JOBS_ACTIVE}${instanceId}', function(err, count) {
			if (err != null) {
				trace(err);
				redis.errorEventLog(err);
				promise.boundPromise.reject(err);
			} else {
				promise.resolve(count);
			}
		});
		return promise.boundPromise;
	}

	function getInstancesHealthStatus(instanceId :MachineId) :Promise<WorkerHealthStatus>
	{
		var promise = new DeferredPromise();
		var key = '${REDIS_KEY_PREFIX_WORKER_HEALTH_STATUS}${instanceId}';
		redis.get(key, function(err, healthString) {
			if (err != null) {
				trace(err);
				redis.errorEventLog(err);
				promise.boundPromise.reject(err);
			} else {
				promise.resolve(healthString.asString());
			}
		});
		return promise.boundPromise;
	}

	function isInstanceHealthy(instanceId :MachineId) :Promise<Bool>
	{
		var promise = new DeferredPromise();
		redis.hget(REDIS_MACHINE_LAST_STATUS, '$instanceId', function(err, status) {
			if (err != null) {
				trace(err);
				redis.errorEventLog(err);
				promise.boundPromise.reject(err);
			} else {
				promise.resolve(status.asString() == WorkerStatus.OK);
			}
		});
		return promise.boundPromise;
	}

	function getInstancesReadyForTermination(type :AsgType) :Promise<Array<MachineId>>
	{
		redis.infoLog({f:'getInstancesReadyForTermination'});
		var workersReadyToDie :Array<String> = [];

		return getInstanceIds(type)
			.pipe(function(instanceIds) {
				redis.debugLog({f:'getInstancesReadyForTermination', instanceIds: instanceIds});
				var promises = instanceIds.map(function(instanceId) {
					redis.debugLog({f:'getInstancesReadyForTermination', instanceId: instanceId});
					return getJobCount(instanceId)
						.pipe(function(count) {
							redis.debugLog({f:'getInstancesReadyForTermination', instanceId: instanceId, jobs:count});
							if (count == 0) {
								return isInstanceCloseEnoughToBillingCycle(instanceId)
									.then(function(okToTerminate) {
										if (okToTerminate) {
											workersReadyToDie.push(instanceId);
										} else {
											redis.debugLog({f:'getInstancesReadyForTermination', instanceId: instanceId, message:'NOT because too close to billing cycle'});
										}
										return true;
									});
							} else {
								redis.debugLog({f:'getInstancesReadyForTermination', instanceId: instanceId, message:'NOT because job count=${count}'});
								return Promise.promise(true);
							}
						});
				});
				return Promise.whenAll(promises);
			})
			.then(function(_) {
				redis.debugLog({workersReadyToDie: workersReadyToDie});
				return workersReadyToDie;
			});
	}

	function getTimeSinceInstanceStarted(id :MachineId) :Promise<Float>
	{
		throw 'override getTimeSinceInstanceStarted';
		return Promise.promise(0.0);
	}

	/**
	 * All, including GPU instances
	 * @return [description]
	 */
	function getAllInstanceIds() :Promise<Array<String>>
	{
		return getInstanceIds(AsgType.CPU)
			.pipe(function(idsCpu) {
				return getInstanceIds(AsgType.GPU)
					.then(function(idsGpu) {
						return ArrayTools.removeDuplicates(idsCpu.concat(idsGpu));
					});
			});
	}

	function getInstanceIds(type :AsgType) :Promise<Array<String>>
	{
		throw 'override getInstanceIds';
		return Promise.promise([]);
	}

	function isInstanceCloseEnoughToBillingCycle(instanceId :String) :Promise<Bool>
	{
		throw 'override isInstanceCloseEnoughToBillingCycle';
		return Promise.promise(true);
	}


}