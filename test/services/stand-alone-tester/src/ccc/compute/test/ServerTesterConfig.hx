package ccc.compute.test;

@:build(util.NodejsMacros.addProcessEnvVars())
class ServerTesterConfig
{
	@NodeProcessVar
	public static var DCC :String = 'dcc.local';

	@NodeProcessVar
	public static var DCC_WORKER1CPU :String;

	@NodeProcessVar
	public static var DCC_WORKER1GPU :String;

	@NodeProcessVar
	public static var DCC_SCALING :String = 'dcc-scaling-server:4015';

	@NodeProcessVar
	public static var LOG_LEVEL :String = 'debug';

	/**
	 * If this env var is not set, then tests
	 * that require access to the redis db will
	 * not be performed
	 */
	@NodeProcessVar
	public static var REDIS_HOST :String;

	@NodeProcessVar
	public static var REDIS_PORT :Int = 6379;

	@NodeProcessVar
	public static var TEST :Bool = false;

	@NodeProcessVar
	public static var TEST_SCALING :Bool = false;

	@NodeProcessVar
	public static var TRAVIS :Int = 0;

	@NodeProcessVar
	public static var TRAVIS_REPO_SLUG :String;

	public static function toJson() :Dynamic
	{
		return {
			'DCC': DCC,
			'LOG_LEVEL': LOG_LEVEL,
			'REDIS_HOST': REDIS_HOST,
			'REDIS_PORT': REDIS_PORT,
		};
	}
}