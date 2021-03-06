package ccc.compute.worker;

import util.DockerTools;

class WorkerStateManager
{
	public var ready :Promise<Bool>;

	@inject public var _injector :Injector;
	@inject public var _redisClients :ServerRedisClient;
	@inject public var _docker :Docker;
	var _id :MachineId;
	var _redis :RedisClient;
	var _monitorTimerId :Dynamic;
	var log :AbstractLogger;

	@post
	public function postInject()
	{
		Assert.notNull(_redisClients);
		Assert.notNull(_redisClients.client);
		Assert.notNull(_docker);
		_redis = _redisClients.client;

		ready = WorkerStateRedis.init(_redisClients.client)
			.pipe(function(_) {
				return ccc.lambda.RedisLogGetter.init(_redisClients.client);
			})
			.pipe(function(_) {
				return initializeThisWorker(_injector)
					.then(function(_) {
						_id = _injector.getValue(MachineId);
						log = Log.child({machineId:_id});
						var workerStatusStream = createWorkerStatusStream(_injector);

						workerStatusStream.then(function(workerState :WorkerState) {
							if (workerState.command != null) {
								switch(workerState.command) {
									case PauseHealthCheck:
										log.debug('Pausing health checks');
										pauseSelfMonitor();
									case UnPauseHealthCheck:
										log.debug('Resuming health checks');
										resumeSelfMonitor();
									case HealthCheck:
										log.debug('Manually triggered health check');
										registerHealthStatus();
									default://
								}
							}
						});
						return true;
					})
					.pipe(function(_) {
						var processQueue = new QueueJobs();
						_injector.map(QueueJobs).toValue(processQueue);
						_injector.injectInto(processQueue);
						return processQueue.ready;
					})
					.then(function(_) {
						resumeSelfMonitor();
						registerHealthStatus();
						return true;
					});
			});
	}

	public function jobCount() :Promise<Int>
	{
		if (_id == null) {
			return Promise.promise(0);
		} else {
			return Jobs.getJobsOnWorker(_id)
				.then(function(jobList) {
					return jobList.length;
				});
		}
	}

	public function resumeSelfMonitor()
	{
		if (_monitorTimerId == null) {
			_monitorTimerId = Node.setInterval(function() {
				registerHealthStatus();
			}, ServerConfig.WORKER_STATUS_CHECK_INTERVAL_SECONDS * 1000);
		}
	}

	public function pauseSelfMonitor()
	{
		if (_monitorTimerId != null) {
			Node.clearInterval(_monitorTimerId);
			_monitorTimerId = null;
		}
	}

	public function registerHealthStatus() :Promise<Bool>
	{
		return getDiskUsage()
			.pipe(function(usage :Float) {
				return WorkerStateRedis.setDiskUsage(_id, usage)
					.then(function(_) {
						return usage;
					});
			})
			.pipe(function(usage :Float) {
				var ok = usage < 0.9;
				if (ok) {
					return setHealthStatus(WorkerHealthStatus.OK);
				} else {
					Log.error({message: 'Failed health check', status:WorkerHealthStatus.BAD_DiskFull});
					return setHealthStatus(WorkerHealthStatus.BAD_DiskFull);
				}
			})
			.errorPipe(function(err) {
				Log.error({error:err, message: 'Failed health check'});
				return setHealthStatus(WorkerHealthStatus.BAD_Unknown)
					.thenTrue()
					.errorPipe(function(err) {
						Log.error({error:err, f:'registerHealthStatus'});
						return Promise.promise(true);
					});
			});
	}

	public function setHealthStatus(status :WorkerHealthStatus) :Promise<Bool>
	{
		log.debug(LogFieldUtil.addWorkerEvent({status:status}, status == WorkerHealthStatus.OK ? WorkerEventType.HEALTHY : WorkerEventType.UNHEALTHY));
		return WorkerStateRedis.setHealthStatus(_id, status);
	}

	function getDiskUsage() :Promise<Float>
	{
		return switch (ServerConfig.CLOUD_PROVIDER_TYPE) {
			case Local:
				// The local provider cannot actually check the local disk,
				// it is unknown where it should be mounted.
				Promise.promise(0.1);
			case AWS:
				getDockerDiskUsageAWS(_docker);
			default: throw 'Invalid CLOUD_PROVIDER_TYPE=${ServerConfig.CLOUD_PROVIDER_TYPE}, valid values: [${CloudProviderType.Local}, ${CloudProviderType.AWS}]';
		}
	}

	public function new() {}

	static function initializeThisWorker(injector :Injector) :Promise<Bool>
	{
		return getWorkerId(injector)
			.pipe(function(id) {
				Assert.notNull(id, 'workerId is null');
				injector.map(MachineId).toValue(id);
				var retrievedWorkerId :MachineId = injector.getValue(MachineId);
				Assert.notNull(retrievedWorkerId, 'retrievedWorkerId is null');
				var docker = injector.getValue(Docker);
				return DockerPromises.info(docker)
					.pipe(function(dockerinfo) {

						//The local 'worker' actually has a bunch of VCPUs,
						//but lets set this to 1 here otherwise it is not
						//really simulating a cloud worker
						switch(ServerConfig.CLOUD_PROVIDER_TYPE) {
							case Local: dockerinfo.NCPU = 1;
							case AWS:
						}

						//If this value is set from the environment
						//use it instead of the value from the docker
						//daemon. This is only used for testing purposes.
						if (ServerConfig.CPUS != null && ServerConfig.CPUS > 0) {
							dockerinfo.NCPU = ServerConfig.CPUS;
						}

						//GPU jobs each implicitly require a CPU
						if (ServerConfig.GPUS > 0) {
							dockerinfo.NCPU = Math.ceil(Math.max(dockerinfo.NCPU - ServerConfig.GPUS, 0));
						}

						return WorkerStateRedis.initializeWorker(id, dockerinfo, ServerConfig.GPUS > 0 ? '${ServerConfig.GPUS}' : '0');
					});
			});
	}

	static function createWorkerStatusStream(injector :Injector)
	{
		var redis :RedisClient = injector.getValue(RedisClient);
		var id :MachineId = injector.getValue(MachineId);
		var workerStatusStream :Stream<WorkerState> =
			RedisTools.createStreamCustom(
				redis,
				WorkerStateRedis.getWorkerStateNotificationKey(id),
				function(command :WorkerUpdateCommand) {
					return WorkerStateRedis.get(id)
						.then(function(workerState) {
							workerState.command = command;
							return workerState;
						});
				}
			);
		workerStatusStream.catchError(function(err) {
			Log.error({error:err, message: 'Failure on workerStatusStream'});
		});
		injector.map("promhx.Stream<ccc.WorkerState>", "WorkerStream").toValue(workerStatusStream);
		return workerStatusStream;
	}


	static function getWorkerId(injector :Injector) :Promise<MachineId>
	{
		return switch(ServerConfig.CLOUD_PROVIDER_TYPE) {
			case Local:
				var docker = injector.getValue(Docker);
				var id :MachineId = DockerTools.getContainerId();
				return Promise.promise(id);
			case AWS:
				return RequestPromises.get('http://169.254.169.254/latest/meta-data/instance-id')
					.then(function(instanceId) {
						instanceId = instanceId.trim();
						return instanceId;
					});
			default: throw 'Invalid CLOUD_PROVIDER_TYPE=${ServerConfig.CLOUD_PROVIDER_TYPE}, valid values: [${CloudProviderType.Local}, ${CloudProviderType.AWS}]';
		}
	}

	static function getDockerDiskUsageAWS(docker :Docker) :Promise<Float>
	{
		var volumes :Array<MountedDockerVolumeDef> = [
			{
				mount: '/var/lib/docker',
				name: '/var/lib/docker'
			}
		];
		return DockerTools.runDockerCommand(docker, DOCKER_IMAGE_DEFAULT, ["df", "-h", "/var/lib/docker/"], null, volumes)
			.then(function(runResult) {
				var diskUse = ~/.*Mounted on\r\n.+\s+.+\s+.+\s+([0-9]+)%.*/igm;
				if (runResult.StatusCode == 0 && diskUse.match(runResult.stdout)) {
					var diskUsage = Std.parseFloat(diskUse.matched(1)) / 100.0;
					Log.debug({disk:diskUsage});
					return diskUsage;
				} else {
					Log.warn('getDockerDiskUsageAWS: Non-zero exit code or did not match regex: ${runResult}');
					return 1.0;
				}
			});
	}
}
