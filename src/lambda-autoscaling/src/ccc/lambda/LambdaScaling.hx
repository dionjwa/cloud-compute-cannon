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
	static var REDIS_KEY_LAST_SCALE_DOWN_TIME_CPU = 'dcc::last-scale-down-time-cpu';
	static var REDIS_KEY_LAST_SCALE_DOWN_TIME_GPU = 'dcc::last-scale-down-time-gpu';

	static function getIntEnvVar(name :String, defaultValue :Int) :Int
	{
		return Node.process.env.get(name) != null && Node.process.env.get(name) != ""
		? Std.parseInt(Node.process.env.get(name))
		: defaultValue;
	}

	public static var MINUTES_AFTER_LAST_JOB_REMOVE_WORKER_GPU :Int  = getIntEnvVar('MINUTES_AFTER_LAST_JOB_REMOVE_WORKER_GPU', 15);
	public static var MINUTES_AFTER_LAST_JOB_REMOVE_WORKER_CPU :Int  = getIntEnvVar('MINUTES_AFTER_LAST_JOB_REMOVE_WORKER_CPU', 10);
	public static var MIN_SCALE_DOWN_INTERVAL_CPU :Int  = getIntEnvVar('MIN_SCALE_DOWN_INTERVAL_CPU', 10);
	public static var MIN_SCALE_DOWN_INTERVAL_GPU :Int  = getIntEnvVar('MIN_SCALE_DOWN_INTERVAL_GPU', 10);

	/**
	 * Logging each log statement separately actually make it more difficult to
	 * follow when using the AWS console, or kibana. These logs need to be
	 * packaged up into a single report UNLESS errors occur.
	 */
	var _report :{base:Array<String>,cpu:Array<String>,gpu:Array<String>};

	static function getRedisClient(opts :RedisOptions) :Promise<RedisClient>
	{
		var redisParams = {
			port: opts.port,
			host: opts.host
		}
		var client = Redis.createClient(opts);
		var promise = new DeferredPromise();
		client.once(RedisEvent.Connect, function() {
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

	public function new()
	{
		_report = {cpu:[], gpu:[], base:[]};
	}

	/**
	 * See docs for the _report var
	 */
	public function log(type :AsgType, message :String, ?pos :haxe.PosInfos)
	{
		var locationString = '';
		if (pos != null) {
			locationString = '${pos.fileName}:${pos.lineNumber}';
		}

		message = '${locationString + " "}${message}';
		switch(type) {
			case CPU: _report.cpu.push(message);
			case GPU: _report.gpu.push(message);
			default:  _report.base.push(message);
		}
	}

	/**
	 * Finally log the details
	 */
	public function report()
	{
		//AWS lambda lots strip whitespace but I want these logs indented
		var indent = '\n.   ';
		var finalReport = '${_report.base.join("\n")}\nCPU:${indent}${_report.cpu.join(indent)}\nGPU:${indent}${_report.gpu.join(indent)}';
		trace(finalReport);
		redis.infoLog(finalReport, true);
	}

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
		return getAllWorkerIds()
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

						// trace('instanceIds=${instanceIds}');
						// trace('dbMembers=${dbMembers}');
						// trace('allMembers=${allMembers}');
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

	public function scale() :Promise<Bool>
	{
		return Promise.promise(true)
			.pipe(function(_) {
				return preChecks();
			})
			.pipe(function(_) {

				function scaleInternal(type :AsgType) {
					return scaleUp(type)
						.pipe(function(wasScaleUpAction) {
							if (wasScaleUpAction) {
								//Don't scale down if there was a scale up
								return Promise.promise(wasScaleUpAction);
							} else {
								return scaleDown(type);
							}
						});
				}

				return Promise.whenAll([
					scaleInternal(AsgType.CPU),
					scaleInternal(AsgType.GPU),
				])
				.then(function(scaleResults) {
					log(null, 'scaleResults=${scaleResults}');
					//Return true if scaled up or down
					return scaleResults[0] || scaleResults[1];
				});
			})
			.pipe(function(scaledUpOrDown) {
				//Only run postchecks if we didn't scale up or down
				log(null, 'scaledUpOrDown=$scaledUpOrDown');
				if (scaledUpOrDown) {
					return Promise.promise(true);
				} else {
					return Promise.promise(true)
						.pipe(function(_) {
							return postChecks();
						});
				}
			});
	}

	public function scaleDown(type :AsgType) :Promise<Bool>
	{
		log(type, 'scaleDown');
		return isReadyToScaleDown(type)
			.pipe(function(canScaleDown) {
				if (canScaleDown) {
					return getMinMaxDesired(type)
						.pipe(function(minMax) {
							var NewDesiredCapacity = minMax.MinSize;

							if (minMax.DesiredCapacity - NewDesiredCapacity > 0) {

								redis.infoLog({
									op: 'ScaleDown',
									current: minMax,
									NewDesiredCapacity: NewDesiredCapacity,
									instancesToKill: minMax.DesiredCapacity - NewDesiredCapacity
								}.add(LogEventType.WorkersScaleDown).addWorkerEvent(WorkerEventType.SCALE_DOWN), true);

								log(type, 'max=${minMax.MaxSize} min=${minMax.MinSize} NewDesiredCapacity=${NewDesiredCapacity} instancesToKill=${minMax.DesiredCapacity - NewDesiredCapacity}');
								return setDesiredCapacity(type, NewDesiredCapacity)
									.pipe(function(resultStatememt) {
										log(type, 'resultStatememt=${resultStatememt}');
										redis.infoLog(resultStatememt, true);
										return setLastScaleDownTime(type);
									});
							} else {
								log(type, 'NewDesiredCapacity=$NewDesiredCapacity currentDesiredCapacity=${minMax.DesiredCapacity}');
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
		log(type, 'scaleUp');
		return Promise.promise(true)
			.pipe(function(_) {
				return getQueueSize(type);
			})
			.pipe(function(queueLength) {
				log(type, 'queueLength=${queueLength}');
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
							// redis.debugLog({
							// 	op: 'ScaleUp',
							// 	MinSize: minMax.MinSize,
							// 	MaxSize: minMax.MaxSize,
							// 	DesiredCapacity: minMax.DesiredCapacity,
							// 	queueLength: queueLength
							// });


							var currentDesiredCapacity = minMax.DesiredCapacity;
							var newDesiredCapacity = currentDesiredCapacity + 1;
							var message = 'max=${minMax.MaxSize} min=${minMax.MinSize} new=${newDesiredCapacity} current=${currentDesiredCapacity}';
							log(type, message);
							if (newDesiredCapacity <= minMax.MaxSize && minMax.DesiredCapacity < minMax.MaxSize) {
								redis.infoLog({type:type, message:message}.addWorkerEvent(WorkerEventType.SCALE_UP), true);
								return setDesiredCapacity(type, newDesiredCapacity)
									.pipe(function(resultStatememt) {
										log(type, 'resultStatememt=${resultStatememt}');
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
		log(null, 'WorkerStateRedis.terminate $id');
		return WorkerStateRedis.terminate(redis, id)
			.thenTrue();
	}

	public function setDesiredCapacity(type :AsgType, workerCount :Int) :Promise<String>
	{
		throw 'override setDesiredCapacity';
		return Promise.promise('override');
	}

	function getTimeLastJobFinished(type :AsgType) :Promise<Float>
	{
		var queueName = switch(type) {
			case CPU: BullQueueNames.JobQueue;
			case GPU: BullQueueNames.JobQueueGpu;
			default: throw 'Unsupported type=$type';
		};
		return RedisPromises.hget(redis, REDIS_HASH_TIME_LAST_JOB_FINISHED, queueName)
			.then(function(time) {
				if (time != null && time != "") {
					return Std.parseFloat(time);
				} else {
					return 0;
				}
			});
	}

	function isTimeSinceLastJobExceedingMinimum(type :AsgType) :Promise<Bool>
	{
		return getTimeLastJobFinished(type)
			.then(function(jobFinishedTime) {
				jobFinishedTime = jobFinishedTime == -1 ? 0 : jobFinishedTime;
				var minIntervalMs = (type == AsgType.CPU ? MINUTES_AFTER_LAST_JOB_REMOVE_WORKER_CPU : MINUTES_AFTER_LAST_JOB_REMOVE_WORKER_GPU) * 60 * 1000;
				var now = Date.now().getTime();
				var interval = now - jobFinishedTime;
				var isWithingRange = interval > minIntervalMs;
				log(type, 'isWithingRange=${isWithingRange}, last job ${PrettyMs.pretty(interval)} ago, min interval=${PrettyMs.pretty(minIntervalMs)}, jobFinishedTime=${jobFinishedTime}');
				return isWithingRange;
			});
	}

	function isReadyToScaleDown(type :AsgType) :Promise<Bool>
	{
		return getQueueSize(type)
			.pipe(function(queueLength) {
				log(type, 'queueLength=${queueLength}');
				if (queueLength > 0) {
					return Promise.promise(false);
				} else {
					return isTimeSinceLastJobExceedingMinimum(type)
					;
				}
			})
			.pipe(function(isLastJobTimeLongAgoEnough) {
				log(type, 'isLastJobTimeLongAgoEnough=${isLastJobTimeLongAgoEnough}');
				if (!isLastJobTimeLongAgoEnough) {
					return Promise.promise(false);
				} else {
					return isLastScaleDownTimeOverMinimum(type);
				}
			});
	}

	function setLastScaleDownTime(type :AsgType) :Promise<Bool>
	{
		var key = type == AsgType.GPU ? REDIS_KEY_LAST_SCALE_DOWN_TIME_GPU : REDIS_KEY_LAST_SCALE_DOWN_TIME_CPU;
		return RedisPromises.set(redis, key, '${Date.now().getTime()}').thenTrue();
	}

	function isLastScaleDownTimeOverMinimum(type :AsgType) :Promise<Bool>
	{
		var key = type == AsgType.GPU ? REDIS_KEY_LAST_SCALE_DOWN_TIME_GPU : REDIS_KEY_LAST_SCALE_DOWN_TIME_CPU;
		return RedisPromises.get(redis, key)
			.then(function(timeString) {
				var lastScaleDownTime = timeString == null ? 0 : Std.parseFloat(timeString);
				var msMinInterval = (switch(type) {
					case CPU: MIN_SCALE_DOWN_INTERVAL_CPU;
					case GPU: MIN_SCALE_DOWN_INTERVAL_GPU;
					case SERVER: throw 'Cannot ever be here';
				}) * 60 * 1000;
				var scaledDownIntervalLongEnough = (Date.now().getTime() - lastScaleDownTime) > msMinInterval;
				log(type, 'scaledDownIntervalLongEnough=${scaledDownIntervalLongEnough} msMinInterval=${PrettyMs.pretty(msMinInterval)} lastScaleDownTime=${PrettyMs.pretty(lastScaleDownTime)}');
				return scaledDownIntervalLongEnough;
			});
	}

	function updateActiveWorkerIdsInRedis() :Promise<Bool>
	{
		return getAllWorkerAndServerIds()
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
		return getAllWorkerIds()
			.pipe(function(instanceIds) {
				return RedisPromises.smembers(redis, WorkerStateRedis.REDIS_MACHINES_ACTIVE)
					.pipe(function(dbMembers) {
						var promises = [];
						for (dbInstanceId in dbMembers) {
							if (!instanceIds.has(dbInstanceId)) {
								log(null, '$dbInstanceId not running, removing from active set');
								redis.debugLog({message:'$dbInstanceId not running, removing from active set'}, true);
								promises.push(RedisPromises.srem(redis, WorkerStateRedis.REDIS_MACHINES_ACTIVE, dbInstanceId));
							}
						}
						return Promise.whenAll(promises)
							.thenTrue();
					});
			});
	}

	function getMinMaxDesired(type :AsgType) :Promise<MinMaxDesired>
	{
		throw 'override getMinMaxDesired';
		return Promise.promise(null);
	}

	function removeUnhealthyWorkers(type :AsgType) :Promise<Bool>
	{
		// redis.infoLog('removeUnhealthyWorkers');
		return getInstanceIds(type)
			.pipe(function(instanceIds) {
				// trace('instanceIds=$instanceIds');
				var promises = instanceIds.map(function(instanceId) {
					return isInstanceHealthy(instanceId)
						.pipe(function(isHealthy) {
							// trace('instanceId=$instanceId isHealthy=$isHealthy');
							if (!isHealthy) {
								//Double check, if the instance just started, it may not have had time
								//to initialize
								return getTimeSinceInstanceStarted(instanceId)
									.pipe(function(timeMilliseconds) {
										var timeSeconds = timeMilliseconds / 1000;
										if (timeSeconds < 600) {//10mins
											// redis.debugLog({instanceId:instanceId, message:'Not terminating potentially sick worker since it just stared up $instanceId'});
											return Promise.promise(true);
										} else {
											log(type, 'removeUnhealthyWorkers terminating instanceId=$instanceId isHealthy=$isHealthy TimeSecondsSinceInstanceStarted=${timeSeconds}');
											redis.infoLog(LogFieldUtil.addWorkerEvent({type:type, instanceId:instanceId, message:'Terminating ${instanceId}'}, WorkerEventType.TERMINATE), true);
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
			case SERVER: throw 'Servers do not have queues';
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

	function getTimeSinceInstanceStarted(id :MachineId) :Promise<Float>
	{
		throw 'override getTimeSinceInstanceStarted';
		return Promise.promise(0.0);
	}

	/**
	 * All, including GPU instances
	 * @return [description]
	 */
	function getAllWorkerIds() :Promise<Array<String>>
	{
		return getInstanceIds(AsgType.CPU)
			.pipe(function(idsCpu) {
				return getInstanceIds(AsgType.GPU)
					.then(function(idsGpu) {
						return ArrayTools.removeDuplicates(idsCpu.concat(idsGpu));
					});
			});
	}

	function getAllWorkerAndServerIds() :Promise<Array<String>>
	{
		return getInstanceIds(AsgType.SERVER)
			.pipe(function(idsServer) {
				return getAllWorkerIds()
					.then(function(idsWorkers) {
						return ArrayTools.removeDuplicates(idsServer.concat(idsWorkers));
					});
			});
	}

	function getInstanceIds(type :AsgType) :Promise<Array<String>>
	{
		throw 'override getInstanceIds';
		return Promise.promise([]);
	}
}