package ccc.scaling;
/**
 * This is to test the lambda scripts locally
 */

class LambdaScalingLocal
	extends LambdaScaling
{
	@inject public var injector :Injector;
	@inject public var docker :Docker;

	@post
	public function postInject()
	{
		setRedis(injector.getValue(RedisClient));
	}

	public function new() {super();}

	override function setDesiredCapacity(type :AsgType, desiredWorkerCount :Int) :Promise<String>
	{
		return ScalingCommands.setDesired(desiredWorkerCount);
	}

	override public function scaleDown(type :AsgType) :Promise<Bool>
	{
		return super.scaleDown(type)
			.pipe(function(result) {
				return preChecks()
					.pipe(function(_) {
						return postChecks()
							.then(function(_) {
								return result;
							});
					});
			});
	}

	override function getInstanceIds(type :AsgType) :Promise<Array<String>>
	{
		return ScalingCommands.getAllDockerWorkerIds();
	}

	public function removeIdleWorkers(type :AsgType, maxWorkersToRemove :Int) :Promise<Array<String>>
	{
		return getInstancesReadyForTermination(type)
			.pipe(function(workerIds) {
				var promises = [];
				var workerIdsRemoved = [];
				while(workerIds.length > 0 && promises.length < maxWorkersToRemove) {
					var id = workerIds.pop();
					workerIdsRemoved.push(id);
					promises.push(ScalingCommands.killWorker(id));
				}
				return Promise.whenAll(promises)
					.then(function(_) {
						return workerIdsRemoved;
					});
			});
	}

	override public function terminateWorker(id :MachineId) :Promise<Bool>
	{
		return super.terminateWorker(id)
			.pipe(function(_) {
				Log.debug('ScalingCommands.killWorker($id)');
				return ScalingCommands.killWorker(id);
			});
	}

	override function getMinMaxDesired(type :AsgType) :Promise<MinMaxDesired>
	{
		return ScalingCommands.getState();
	}

	override function getTimeSinceInstanceStarted(id :MachineId) :Promise<Float>
	{
		return Promise.promise(1000*60*60.0);
		// return DockerPromises.inspect(docker.getContainer(id))
		// 	.then(function(containerData) {
		// 		var timeString = containerData.Created;
		// 		var timeStarted :Float = untyped __js__('Date.parse({0})', timeString);
		// 		return Date.now().getTime() - timeStarted;
		// 	});
	}
}