package ccc.compute.test.tests;

class TestJobCleanup extends ServerAPITestBase
{
	@inject public var redis :RedisClient;

	@timeout(240000)
	public function testBasicJobSuccessCleanedUpFromRedisAndStorage() :Promise<Bool>
	{
		var routes = ProxyTools.getProxy(_serverHostRPCAPI);
		var queues :Queues = ServerTestTools.getQueues(injector);
		var testBlob = createTestJobAndExpectedResults('testBasicJobSuccessCleanedUpFromRedisAndStorage', 0);
		testBlob.request.id = 'testBasicJobSuccessCleanedUpFromRedisAndStorage${ShortId.generate()}';
		var expectedBlob = testBlob.expects;
		var jobRequest = testBlob.request;
		jobRequest.wait = true;
		jobRequest.parameters = {maxDuration:10};

		var jobId :JobId = testBlob.request.id;
		var jobResult :JobResultAbstract = null;

		//Get the storage object the same way the worker logic gets the storage service
		var fs = StorageTools.getStorageLocalDefault();

		//Casting a data structure into another to get the job location tools.
		//Not really a proper conversion, but only interested in the fields they
		//have in common: [inputDir, outputDir, resultDir]
		var job :DockerBatchComputeJob = cast jobRequest;
		var inputStorageRemote = fs.clone().appendToRootPath(job.inputDir());
		var outputStorageRemote = fs.clone().appendToRootPath(job.outputDir());
		var resultsStorageRemote = fs.clone().appendToRootPath(job.resultDir());

		//With bull, this is a safe operation.
		return redis.deleteAllKeys()
			.pipe(function(_) {
				return routes.submitJobJson(jobRequest);
			})
			//Get the result
			.then(function(result :JobResultAbstract) {
				jobResult = result;
				if (jobResult == null) {
					throw 'jobResult should not be null. Check the above section';
				}
				jobId = jobResult.jobId;
			})
			//Check the string is in redis. A bit redundant, but it's technically
			//the control for the test below
			.pipe(function(_) {
				return RedisTestTools.isStringInRedis(ServerTesterConfig.REDIS_HOST, jobId)
					.then(function(isPresent) {
						assertTrue(isPresent);
						return true;
					});
			})
			//Check storage, job stuff should be there, again another control for
			//the proper check below
			.pipe(function(_) {
				var checkTrue = function(name :String, assertThatTrue :Bool) {
					assertTrue(assertThatTrue);
				}
				return Promise.whenAll([
					inputStorageRemote.exists(jobRequest.inputs[0].name).then(checkTrue.bind(jobRequest.inputs[0].name)),
					outputStorageRemote.exists(jobResult.outputs[0]).then(checkTrue.bind(jobResult.outputs[0])),
					resultsStorageRemote.exists(RESULTS_JSON_FILE).then(checkTrue.bind(RESULTS_JSON_FILE)),
				]);
			})
			//Remove job
			.pipe(function(_) {
				return routes.doJobCommand_v2(JobCLICommand.Remove, jobId)
					.pipe(function(_) return RedisTestTools.clearLogs());
			})
			.pipe(function(_) {
				return BullQueueTestTools.waitUntilQueueEmpty(queues.message);
			})
			//Uncomment to see exactly what is in redis
			// .pipe(function(_) {
			// 	return RedisTestTools.getRedisDump(ServerTesterConfig.REDIS_HOST)
			// 		.then(function(dump) {
			// 			trace(Json.stringify(dump, null, '  '));
			// 			traceYellow('$jobId should not be there');
			// 		});
			// })
			//Check redis for the jobId *anywhere*.
			.pipe(function(_) {
				return RedisTestTools.isStringInRedis(ServerTesterConfig.REDIS_HOST, jobId)
					.then(function(isPresent) {
						assertFalse(isPresent);
					});
			})
			//Check storage, job stuff should be gone
			.pipe(function(_) {
				var checkFalse = function(assertThatFalse) {
					assertFalse(assertThatFalse);
				}
				return Promise.whenAll([
					inputStorageRemote.exists(jobRequest.inputs[0].name).then(checkFalse),
					outputStorageRemote.exists(jobResult.outputs[0]).then(checkFalse),
					resultsStorageRemote.exists(RESULTS_JSON_FILE).then(checkFalse),
				]);
			})
			.thenTrue();
	}

	/**
	 * 
	 */
	@timeout(240000)
	public function testRemovingNonexistantJobNoError() :Promise<Bool>
	{
		var routes = ProxyTools.getProxy(_serverHostRPCAPI);
		return routes.doJobCommand_v2(JobCLICommand.Remove, 'fakeJobId')
			.errorPipe(function(err) {
				traceRed(err);
				assertTrue(false);
				return Promise.promise(true);

			})
			.thenTrue();
	}

	/**
	 * Unlike regular jobs, if a turbo job is finished, there is
	 * should be trace of it in redis (or storage).
	 */
	@timeout(240000)
	public function testTurboJobSuccessCleanedUpFromRedis() :Promise<Bool>
	{
		var routes = ProxyTools.getProxy(_serverHostRPCAPI);

		var random = ShortId.generate();

		var inputs :Array<DataBlob> = [];

		var inputName2 = 'in${ShortId.generate()}';

		inputs.push({
			{
				name: inputName2,
				value: 'in${ShortId.generate()}',
				encoding: 'utf8'
			}
		});

		var outputName1 = 'out${ShortId.generate()}';
		var outputValue1 = 'out${ShortId.generate()}';

		var outputValueStdout = 'out${ShortId.generate()}';
		var outputValueStderr = 'out${ShortId.generate()}';
		var script =
'#!/bin/sh
echo "$outputValueStdout"
echo "$outputValueStderr" >> /dev/stderr
mkdir -p /$DIRECTORY_OUTPUTS
echo "$outputValue1" > /$DIRECTORY_OUTPUTS/$outputName1
';
		var scriptName = 'script.sh';

		inputs.push({
			{
				name: scriptName,
				value: script,
				encoding: 'utf8'
			}
		});

		var random = ShortId.generate();

		var jobId :JobId = 'testTurboJobSuccessCleanedUpFromRedis$random';

		var request: BatchProcessRequestTurboV2 = {
			id: jobId,
			inputs: inputs,
			image: DOCKER_IMAGE_DEFAULT,
			command: ["/bin/sh", '/$DIRECTORY_INPUTS/$scriptName'],
			parameters: {maxDuration:30, cpus:1}
		}

		var proxy = ServerTestTools.getProxy();
		return proxy.submitTurboJobJsonV2(request)
			.pipe(function(_) {
				return RedisTestTools.isStringInRedis(ServerTesterConfig.REDIS_HOST, jobId)
					.pipe(function(isPresent) {
						if (isPresent) {
							return RedisTestTools.getRedisDump(ServerTesterConfig.REDIS_HOST)
								.then(function(dump) {
									trace(Json.stringify(dump, null, '  '));
								}).thenTrue();
						} else {
							assertFalse(isPresent);
							return Promise.promise(true);
						}
					});
			})
			.thenTrue();
	}

	public function new() { super(); }
}
