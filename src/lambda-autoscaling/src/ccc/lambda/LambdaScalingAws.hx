package ccc.lambda;

import js.npm.aws_sdk.EC2;
import js.npm.aws_sdk.AutoScaling;

using ccc.RedisLoggerTools;

class LambdaScalingAws
	extends LambdaScaling
{
	/** "" is converted to null */
	static function getStringEnvVar(name :String) :String
	{
		return Node.process.env.get(name) != null && Node.process.env.get(name) != ""
		? Node.process.env.get(name)
		: null;
	}

	static var REDIS_HOST :String  = getStringEnvVar('REDIS_HOST');
	static var ASG_NAME :String  = getStringEnvVar('ASG_NAME');
	static var ASG_GPU_NAME :String  = getStringEnvVar('ASG_GPU_NAME');
	static var ASG_NAME_SERVER :String  = getStringEnvVar('ASG_NAME_SERVER');

	static var autoscaling = new AutoScaling();
	static var ec2 = new EC2();

	var _AutoScalingGroupCpu :AutoScalingGroup = null;
	var _AutoScalingGroupGpu :AutoScalingGroup = null;
	var _AutoScalingGroupServer :AutoScalingGroup = null;

	@:expose('handlerScale')
	static function handlerScale(event :Dynamic, context :Dynamic, callback :js.Error->Dynamic->Void) :Void
	{
		var redis :RedisClient;
		var calledBack = false;

		var scaler = new LambdaScalingAws();

		LambdaScaling.getRedisClient({host:REDIS_HOST, port:6379})
			.pipe(function(client) {
				redis = client;

				scaler.setRedis(redis);

				return scaler.scale()
					.then(function(_) {
						scaler.log(null, 'Finished successfully');
						scaler.report();
						try {
							if (!calledBack) {
								redis.publish(RedisLoggerTools.REDIS_KEY_LOGS_CHANNEL, 'logs');
								redis.quit();
							}
						} catch (err :Dynamic) {

						}
						if (!calledBack) {
							calledBack = true;
							callback(null, 'OK');
						}
					});
			})
			.catchError(function(err) {
				scaler.log(null, '!Error:${err}');
				scaler.report();
				try {
					if (redis != null) {
						// redis.infoLog({message:'Finished with error'});
						redis.errorEventLog(cast err);
						redis.publish(RedisLoggerTools.REDIS_KEY_LOGS_CHANNEL, 'logs');
						redis.quit();
					}
				} catch(err :Dynamic) {
					//Ignored
					trace(err);
				}
				if (!calledBack) {
					calledBack = true;
					callback(cast err, null);
				}
			});
	}

	public function new()
	{
		super();
	}

	override public function setDesiredCapacity(type :AsgType, desiredWorkerCount :Int) :Promise<String>
	{
		return getAutoScalingGroup(type)
			.pipe(function(asg :AutoScalingGroup) {
				if (asg == null) {
					return Promise.promise('No ASG type=$type, ignoring desiredWorkerCount=$desiredWorkerCount');
				}
				var promise = new DeferredPromise();
				var params = {
					AutoScalingGroupName: asg.AutoScalingGroupName,
					DesiredCapacity: desiredWorkerCount,
					HonorCooldown: true
				};
				log(type, 'setDesiredCapacity({ DesiredCapacity:${desiredWorkerCount} })');
				redis.infoLog(LogFieldUtil.addWorkerEvent(Reflect.copy(params), WorkerEventType.SET_WORKER_COUNT), true);
				autoscaling.setDesiredCapacity(params, function(err, data) {
					if (err != null) {
						promise.boundPromise.reject(err);
					} else {
						log(type, 'setDesiredCapacity result ${asg.DesiredCapacity}=>${desiredWorkerCount} ${Json.stringify(data)}');
						promise.resolve('type=$type DesiredCapacity ${asg.DesiredCapacity} => ${desiredWorkerCount}');
					}
				});
				return promise.boundPromise;
			});
	}

	override function getInstanceIds(type :AsgType) :Promise<Array<String>>
	{
		return getAutoScalingGroup(type)
			.then(function(asg :AutoScalingGroup) {
				if (asg != null) {
					return asg.Instances.map(function(i) {
						return i.InstanceId;
					});
				} else {
					return [];
				}
			});
	}

	override function getMinMaxDesired(type :AsgType) :Promise<MinMaxDesired>
	{
		return getAutoScalingGroup(type)
			.then(function(asg :AutoScalingGroup) {
				if (asg != null) {
					return {
						MinSize: asg.MinSize,
						MaxSize: asg.MaxSize,
						DesiredCapacity: asg.DesiredCapacity
					};
				} else {
					return {
						MinSize: 0,
						MaxSize: 0,
						DesiredCapacity: 0
					};
				}
			});
	}

	/**
	 * Returns the AutoScalingGroup name with the
	 * tag: stack=<stackKeyValue>
	 */
	function getAutoScalingGroupName(type :AsgType) :Promise<String>
	{
		return getAutoScalingGroup(type)
			.then(function(asg :AutoScalingGroup) {
				return asg != null ? asg.AutoScalingGroupName : null;
			});
	}

	static function isValidAsgName(name :String) :Bool
	{
		return name != null && name.length > 2;
	}

	function getAutoScalingGroup(type :AsgType) :Promise<AutoScalingGroup>
	{
		if (type == null) {
			throw 'getAutoScalingGroup type ==  null';
		}

		//Quickly return under some conditions
		switch(type) {
			case CPU:
				if (!isValidAsgName(ASG_NAME)) {
					return Promise.promise(null);
				} else if (_AutoScalingGroupCpu != null) {
					return Promise.promise(_AutoScalingGroupCpu);
				}
			case GPU:
				if (!isValidAsgName(ASG_GPU_NAME)) {
					return Promise.promise(null);
				} else if (_AutoScalingGroupGpu != null) {
					return Promise.promise(_AutoScalingGroupGpu);
				}
			case SERVER:
				if (!isValidAsgName(ASG_NAME_SERVER)) {
					return Promise.promise(null);
				} else if (_AutoScalingGroupServer != null) {
					return Promise.promise(_AutoScalingGroupServer);
				}
		}

		var promise = new DeferredPromise();
		var params :DescribeAutoScalingGroupsParams = {
			AutoScalingGroupNames: [ switch(type) {
				case CPU: ASG_NAME;
				case GPU: ASG_GPU_NAME;
				case SERVER: ASG_NAME_SERVER;
			}]
		};

		var isResolved = false;
		var cleanup = null;
		var timeoutTimeMilliseconds = 30000;
		var timeoutId = Node.setTimeout(function() {
			cleanup(new js.Error('describeAutoScalingGroups timed out after ${timeoutTimeMilliseconds}ms'), null);
		}, timeoutTimeMilliseconds);//Timeout after 15 seconds

		cleanup = function(err, data) {
			if (isResolved) {
				return;
			}
			isResolved = true;
			if (timeoutId != null) {
				Node.clearTimeout(timeoutId);
				timeoutId = null;
			}
			if (err != null) {
				promise.boundPromise.reject(err);
			} else {
				promise.resolve(data);
			}
		}
		autoscaling.describeAutoScalingGroups(params, function(err, data) {
			if (err != null) {
				redis.errorLog('describeAutoScalingGroups err=$err');
				cleanup(err, null);
				return;
			}
			var asgs = data.AutoScalingGroups != null ? data.AutoScalingGroups : [];
			var asg = asgs[0];
			if (asg != null) {
				switch(type) {
					case CPU: _AutoScalingGroupCpu = asg;
					case GPU: _AutoScalingGroupGpu = asg;
					case SERVER: _AutoScalingGroupServer = asg;
				}
			}
			cleanup(null, asg);
		});

		return promise.boundPromise;
	}

	override function getTimeSinceInstanceStarted(instanceId :MachineId) :Promise<Float>
	{
		return getInstanceInfo(instanceId)
			.then(function(info :Dynamic) {
				if (info == null) {
					return -1.0;
				}
				var now = Date.now().getTime();
				var ageInMilliseconds = now - info.LaunchTime;
				log(null, '$instanceId age=${PrettyMs.pretty(ageInMilliseconds)}');
				return ageInMilliseconds;
			});
	}


	function getInstanceMinutesSinceLaunch(instanceId :MachineId) :Promise<Float>
	{
		return getTimeSinceInstanceStarted(instanceId)
			.then(function(time) {
				return (time / 1000) / 60;
			});
	}

	var instanceInfos :DynamicAccess<Dynamic> = {}
	function getInstanceInfo(instanceId :String, ?disableCache :Bool = false) :Promise<Dynamic>
	{
		if (!disableCache && instanceInfos.get(instanceId) != null) {
			return Promise.promise(instanceInfos.get(instanceId));
		} else {
			var promise = new DeferredPromise();
			var params = {
				InstanceIds: [instanceId]
			};
			ec2.describeInstances(params, function(err :js.Error, data :Dynamic) :Void {
				if (err != null) {
					promise.boundPromise.reject(err);
				} else {
					var instanceData = data && data.Reservations && data.Reservations[0] && data.Reservations[0].Instances && data.Reservations[0].Instances[0];
					instanceInfos.set(instanceId, instanceData);
					promise.resolve(instanceData);
				}
			});
			return promise.boundPromise;
		}
	}

	override function removeUnhealthyWorkers(type :AsgType) :Promise<Bool>
	{
		// trace('removeUnhealthyWorkers type=$type');
		return getAutoScalingGroup(type)
			.pipe(function(asg) {
				if (asg == null) {
					// redis.infoLog('removeUnhealthyWorkers asg == null');
					return Promise.promise(false);
				}
				//Only concern ourselves with healthy instances.
				var instances = asg.Instances.filter(function(instanceData) {
					return instanceData.LifecycleState == "InService" && instanceData.HealthStatus == "Healthy";
				});

				var promises :Array<Promise<Bool>> = instances.map(function(instance :{InstanceId:MachineId}) {
					var instanceId :MachineId = instance.InstanceId;
					return getInstancesHealthStatus(instanceId)
						.pipe(function(healthString) {
							if (healthString != 'OK') {
								// redis.infoLog({instanceId:instanceId, healthString:healthString});
								return getInstanceMinutesSinceLaunch(instanceId)
									.pipe(function(minutesSinceLaunch) {
										if (minutesSinceLaunch > 15) {
											// trace('TERMINATING instanceId=$instanceId healthString=$healthString minutesSinceLaunch=$minutesSinceLaunch');
											redis.infoLog({type:type, instanceId:instanceId, message:'!!!!!!Terminating ${instanceId}', status:healthString, minutesSinceLaunch:minutesSinceLaunch});
											return terminateWorker(instanceId)
												.then(function(_) {
													return true;
												});
										} else {
											// redis.infoLog({instanceId:instanceId, message:'NOT Terminating ${instanceId}', status:healthString, minutesSinceLaunch:minutesSinceLaunch});
											return Promise.promise(true);
										}
									});
							} else {
								// trace('instanceId=$instanceId healthString=$healthString');
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

	override public function terminateWorker(id :MachineId) :Promise<Bool>
	{
		return super.terminateWorker(id)
			.pipe(function(_) {
				var promise = new DeferredPromise();
				var params = { InstanceIds: [id] };
				redis.infoLog({f:'terminateInstances', instanceId:id});
				ec2.terminateInstances(params, function(err, data) {
					if (err != null) {
						redis.errorEventLog(err, 'ec2.terminateInstances');
						promise.boundPromise.reject(err);
					} else {
						promise.resolve(true);
					}
				});
				return promise.boundPromise;
			});
	}

	function isAsg(type :AsgType) :Promise<Bool>
	{
		return getAutoScalingGroup(type)
			.then(function(asg) {
				return asg != null;
			});
	}
}