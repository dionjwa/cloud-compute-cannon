package ccc.compute.test.tests;

class TestMetaframe
	extends haxe.unit.async.PromiseTest
{
	/**
	 * As long as it returns a 200 response (no error thrown)
	 * we assume the metaframe is ok. This could be more
	 * sophisticated but for now it's just a sanity check.
	 */
	@timeout(2000)
	public function testMetapage() :Promise<Bool>
	{
		var url = 'http://${ServerTesterConfig.CCC}/metaframe/';
		trace('url=${url}');
		return RequestPromises.get(url)
			.then(function(result) {
				return true;
			});
	}

	@timeout(2000)
	public function testMetapageLibs() :Promise<Bool>
	{
		var url = 'http://${ServerTesterConfig.CCC}/metaframe/libs.js';
		return RequestPromises.get(url)
			.then(function(result) {
				return true;
			});
	}

	@timeout(2000)
	public function testMetapageClientPackage() :Promise<Bool>
	{
		var url = 'http://${ServerTesterConfig.CCC}/metaframe/index.js';
		return RequestPromises.get(url)
			.then(function(result) {
				return true;
			});
	}
}