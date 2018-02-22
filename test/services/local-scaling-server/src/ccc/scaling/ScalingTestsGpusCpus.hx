package ccc.scaling;

class ScalingTestsGpusCpus
	extends PromiseTest
{
	@inject public var redis :RedisClient;
	@inject public var docker :Docker;
	@inject public var lambda :LambdaScaling;

	/**
	 * Adds GPU and CPU jobs separately and expects that
	 * the individual scaling types handle the resepective
	 * scaling from the separate queues.
	 */
	@timeout(120000)
	public function testGPUAndCPUIndividualScaling() :Promise<Bool>
	{
		Log.debug({event:'testGPUAndCPUIndividualScaling'});
		var workerId :MachineId;
		return Promise.promise(true);
	}

	public function new(){}
}