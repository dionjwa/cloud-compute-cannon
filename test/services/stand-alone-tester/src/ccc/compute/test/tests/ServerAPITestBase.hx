package ccc.compute.test.tests;

class ServerAPITestBase extends haxe.unit.async.PromiseTest
{
	public var _serverHost :Host = ServerTesterConfig.DCC;
	public var _serverHostUrl :UrlString = 'http://${ServerTesterConfig.DCC}';
	public var _serverHostRPCAPI :UrlString = 'http://${ServerTesterConfig.DCC}/${Type.enumConstructor(CCCVersion.v1)}';

	@inject public var injector :Injector;

	public function new()
	{
		_serverHost = ServerTesterConfig.DCC;
		_serverHostUrl = 'http://${ServerTesterConfig.DCC}';
		_serverHostRPCAPI = 'http://${ServerTesterConfig.DCC}/${Type.enumConstructor(CCCVersion.v1)}';
	}
}