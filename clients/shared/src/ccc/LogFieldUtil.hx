package ccc;

class LogFieldUtil
{
	public static function addLogStack(obj :Dynamic, f :LogFieldStack) :Dynamic
	{
		Reflect.setField(obj, '${LogKeys.stack}', f);
		return obj;
	}

	public static function addJobEvent(obj :Dynamic, f :JobEventType) :Dynamic
	{
		Reflect.setField(obj, '${LogKeys.jobevent}', f);
		return obj;
	}

	public static function addWorkerEvent(obj :Dynamic, f :WorkerEventType) :Dynamic
	{
		Reflect.setField(obj, '${LogKeys.workerevent}', f);
		return obj;
	}

	public static function addServerEvent(obj :Dynamic, f :ServerEventType) :Dynamic
	{
		Reflect.setField(obj, '${LogKeys.serverevent}', f);
		return obj;
	}
}