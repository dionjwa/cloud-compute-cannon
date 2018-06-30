package ccc.compute.test.tests;

/**
 * Does NOT actually test docker GPU nividia functionality because
 * local systems likely won't have the hardware.
 *
 * These test that jobs marked as requiring a GPU are only processed
 * properly by the workers that actually think they have a GPU.
 */
class TestGpuJobs extends ServerAPITestBase
{
	/**
	 * Create a bunch of CPU and GPU jobs, enqueue them,
	 * and ensure that:
	 *  - the GPU worker processes GPU jobs and the CPU worker does not
	 *  - the GPU worker can also process CPU jobs
	 *  - the CPU worker must process at least one job
	 */
	@timeout(240000)
	public function testGPUandCPUjobsToCorrectWorkers() :Promise<Bool>
	{
		if (ServerTesterConfig.DCC_WORKER1CPU == null || ServerTesterConfig.DCC_WORKER1GPU == null) {
			traceYellow('Skipping test "testGPUandCPUjobsToCorrectWorkers" because DCC_WORKER1CPU or DCC_WORKER1GPU are undefined');
			return Promise.promise(true);
		}
		this.assertNotNull(ServerTesterConfig.DCC);

		var routes = ProxyTools.getProxy(_serverHostRPCAPI);
		var workersIds = {
			cpu: "",
			gpu: "",
		};
		var duration = 1;
		var jobCount = 4;
		var jobs = {
			cpu: [for (i in 0...jobCount) ServerTestTools.createTestJobAndExpectedResults('testGPUandCPUjobsToCorrectWorkers', duration, false, false)],
			gpu: [for (i in 0...jobCount) ServerTestTools.createTestJobAndExpectedResults('testGPUandCPUjobsToCorrectWorkers', duration, false, true)],
		};
		var jobIds = {
			cpu: [],
			gpu: [],
		};

		return Promise.promise(true)
			//Get the machine ids of both workers
			//Actually try this a few times before failing
			//because startup times can delay worker init
			.pipe(function(_) {
				return RetryPromise.retryRegular(function() {
					return routes.status()
					.then(function(status :SystemStatus) {
						if (status.workers.length != 2) {
							throw 'status.workers.length (${status.workers.length}) != 2';
						}
						return true;
					});
				}, 10, 500);
			})
			.pipe(function(_) {
				return routes.status()
					.then(function(status :SystemStatus) {
						assertEquals(status.workers.length, 2);
						status.workers.iter(function(workerBlob) {
							if (workerBlob.gpus > 0) {
								workersIds.gpu = workerBlob.id;
							} else {
								workersIds.cpu = workerBlob.id;
							}
						});
						return true;
					});
			})
			.pipe(function(_) {
				return routes.status()
					.then(function(status :SystemStatus) {
						assertEquals(status.workers.length, 2);
						status.workers.iter(function(workerBlob) {
							if (workerBlob.gpus > 0) {
								workersIds.gpu = workerBlob.id;
							} else {
								workersIds.cpu = workerBlob.id;
							}
						});
						return true;
					});
			})
			//Enqueue a bunch of CPU and GPU jobs
			.pipe(function(_) {
				function enqueue (index :Int, jobArray :Array<{request:BasicBatchProcessRequest, expects:ExpectedResult}>, jobIdArray :Array<JobId>) :Promise<Bool>  {
					jobArray[index].request.wait = true;
					return ClientJSTools.postJob(_serverHost, jobArray[index].request)
						.then(function(jobResult) {
							jobIdArray[index] = jobResult.jobId;
							return true;
						});
				}

				var promises = [];

				for (i in 0...jobs.cpu.length) {
					promises.push(enqueue(i, jobs.cpu, jobIds.cpu));
					promises.push(enqueue(i, jobs.gpu, jobIds.gpu));
				}

				return Promise.whenAll(promises)
					.thenTrue();
			})
			//Check that 1) all the GPU jobs ran on the GPU worker
			//           2) the non-GPU worker ran *some* jobs
			.pipe(function(_) {

				assertEquals(jobIds.gpu.length, jobCount);
				assertEquals(jobIds.cpu.length, jobCount);

				function confirmRanOnGpu(jobId :JobId) {
					return routes.doJobCommand_v2(JobCLICommand.JobStats, jobId)
						.then(function(jobStats :JobStatsData) {
							assertNotNull(jobStats);
							assertEquals(jobStats.attempts.length, 1);
							assertEquals(jobStats.attempts[0].workerId, workersIds.gpu);
							return true;
						});
				}

				var promises = jobIds.gpu.map(confirmRanOnGpu);

				var someJobsRanOnCpu = false;
				function checkThatAtLeastOneJobWentToCpu(jobId :JobId) {
					return routes.doJobCommand_v2(JobCLICommand.JobStats, jobId)
						.then(function(jobStats :JobStatsData) {
							assertEquals(jobStats.attempts.length, 1);
							if (jobStats.attempts[0].workerId == workersIds.cpu) {
								someJobsRanOnCpu = true;
							}
							return true;
						});
				}
				promises = promises.concat(jobIds.cpu.map(checkThatAtLeastOneJobWentToCpu));

				return Promise.whenAll(promises).thenTrue();
			});
	}

	public function new() { super(); }
}
