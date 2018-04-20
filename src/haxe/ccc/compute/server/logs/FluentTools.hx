package ccc.compute.server.logs;

import haxe.extern.EitherType;

import js.npm.fluentlogger.FluentLogger;

typedef LogObj = {
	var message :Dynamic;
}

class FluentTools
{
	public static function createEmitter(timestampKey :String = '@timestamp', isTimeStampString :Bool = true)
	{
		return function(obj :Dynamic, ?cb :Void->Void) :Void {
			var msg :LogObj = switch(untyped __typeof__(obj)) {
				case 'object': obj;
				default: {message:Std.string(obj)};
			}
			if (Reflect.hasField(msg, 'time')) {
				Reflect.setField(msg, timestampKey,
					isTimeStampString ?
						Reflect.field(msg, 'time').toISOString()
						:
						Reflect.field(msg, 'time').getTime());
			}

			if (Reflect.hasField(msg, '@timestamp')) {
				Reflect.setField(msg, timestampKey,
					isTimeStampString ?
						Reflect.field(msg, '@timestamp').toISOString()
						:
						Reflect.field(msg, '@timestamp').getTime());
			}

			static_emitter(msg, null, cb);
		}
	}

	public static function logToFluent(obj :Dynamic, ?cb :Void->Void)
	{
		createEmitter()(obj, cb);
	}

	static var static_emitter =
		FluentLogger.createFluentSender(null,
			{
				host: ServerConfig.FLUENT_HOST,
				port: ServerConfig.FLUENT_PORT
			}).emit.bind(APP_NAME_COMPACT, _, _, _);
}
