package ccc.compute.test.tests;

class TestMetaframe
	extends haxe.unit.async.PromiseTest
{
	@only
	@timeout(2000)
	public function testMetapage() :Promise<Bool>
	{
		var url = 'http://${ServerTesterConfig.CCC}/metaframe';
		return RequestPromises.get(url)
			.then(function(result) {
				trace('result=${result}');
				return true;
			});
	}
}