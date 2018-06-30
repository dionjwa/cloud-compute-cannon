package ccc.compute.test.tests;

/**
 * Expects a server at "server:9000" and a worker at "worker1:9000"
 */
class TestServerWorkerSplit extends ServerAPITestBase
{
	/**
	 * Check that the local storage system is working correctly
	 * where all servers and workers share the same mounted volume.
	 * This simulates a shared e.g. S3 bucket. If this doesn't work
	 * then later tests will fail in sad ways.
	 */
	@timeout(240000)
	public function testServerAndWorkerAccessSameFileStorage() :Promise<Bool>
	{
		if (ServerTesterConfig.DCC_WORKER1CPU == null) {
			traceYellow('Skipping test "testServerAndWorkerAccessSameFileStorage" because DCC_WORKER1CPU is undefined');
			return Promise.promise(true);
		}
		this.assertNotNull(ServerTesterConfig.DCC);

		var storage = ServiceStorageLocalFileSystem.getService();
		storage.setRootPath(DEFAULT_BASE_STORAGE_DIR);

		var filePath = 'file-${ShortId.generate()}';
		var fileContent = '${ShortId.generate()}';
		var stringStream = StreamTools.stringToStream(fileContent);
		return storage.writeFile('$filePath', stringStream)
			.pipe(function(done) {
				var promises = [
					ServerTesterConfig.DCC,
					ServerTesterConfig.DCC_WORKER1CPU,
					ServerTesterConfig.DCC_WORKER1GPU
				].map(function(host) {
					return RetryPromise.retryRegular(function() {
						return RequestPromises.get('http://${host}/$filePath')
							.then(function(content) {
								assertEquals(content, fileContent);
								return true;
							});
						}, 8, 1000);
				});
				return Promise.whenAll(promises).thenTrue();
			});
	}

	public function new() { super(); }
}
