import haxe.extern.Rest;

import ccc.compute.Definitions;
import ccc.compute.Definitions.Constants.*;

@:keep
class LuaTest
{
	public static function foo()
	{
		// var redis :Redis = new Redis();
		var redis = Redis;
		untyped __lua__('--BEGIN1');
		redis.call("HGET", 'some', JobCLICommand.Remove);
		untyped __lua__('--END1');
	}

	static function main()
	{

		// var test = Redis.call("foo");
		// trace('test');
	}
}

@:expose("redis")
extern class Redis
{
	public function new();
	public static function call(method : String, args :Rest<Dynamic>) : Dynamic;
}