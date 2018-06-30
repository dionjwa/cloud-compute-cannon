package ccc.compute.server.services.ws;

import ccc.metaframe.action.*;
import ccc.metaframe.state.*;

import haxe.Serializer;
import haxe.Unserializer;

import js.react.websocket.WebsocketTools;

import redux.Redux;

import haxe.remoting.JsonRpc;

import js.npm.ws.WebSocket;

class WebsocketConnectionMetaframeJobMonitor
{
	@inject('StatusStream') public var _JOB_STREAM :Stream<JobStatsData>;
	@inject('ActiveJobStream') public var _ACTIVE_JOB_STREAM :Stream<Array<JobId>>;
	@inject('FinishedJobStream') public var _FINISHED_JOB_STREAM :Stream<Array<JobId>>;
	@inject public var injector :Injector;

	var _ws :WebSocket;
	var _stream :Stream<Void>;
	var _activeJobStream :Stream<Void>;
	var _finishedJobStream :Stream<Void>;

	public function new(ws :WebSocket)
	{
		Assert.that(ws != null);
		_ws = ws;
		_ws.on(WebSocketEvent.Message, onMessage);
		_ws.on(WebSocketEvent.Close, onClose);
		_ws.on(WebSocketEvent.Error, function(err) {
			traceRed('err=$err');
			onClose(-1, '$err');
		});
	}

	function runJob(job :JobRequestUnified)
	{
		//Run job (assume turbo for now)
		//and send results back
		var turboJobDef :BatchProcessRequestTurboV2 = {
			inputs: job.Inputs,
			CreateContainerOptions: job.CreateContainerOptions,
			imagePullOptions: job.ImagePullOptions,
			parameters: job.Parameters != null ? job.Parameters : {maxDuration:ServerConfig.JOB_TURBO_MAX_TIME_SECONDS},
			inputsPath: job.InputsPath,
			outputsPath: job.OutputsPath,
			meta: job.Meta,
			ignoreOutputs: job.Parameters != null ? job.Parameters.IgnoreOutputs : false,
			forceUtf8Outputs: job.Parameters != null ? job.Parameters.ForceUtf8Outputs : false,
		};
		if (turboJobDef.parameters.maxDuration == null) {
			turboJobDef.parameters.maxDuration = ServerConfig.JOB_TURBO_MAX_TIME_SECONDS;
		}
		ServiceBatchComputeTools.runTurboJobRequestV2(injector, turboJobDef)
			.then(function(result) {
				sendMessage(MetaframeAction.SetJobResults(result));
			})
			.catchError(function(err) {
				Log.debug({error:err});
				var result :JobResultsTurboV2 = {
					id: null,
					stdout: null,
					stderr: null,
					exitCode: -1,
					outputs: null,
					error: Json.stringify(err),
				};
				sendMessage(MetaframeAction.SetJobResults(result));
			});
	}

	function onMessage(message :Dynamic, flags :Dynamic)
	{
		switch(WebsocketTools.decodeMessage(message)) {
			case ActionMessage(action):
				if (action.type == Type.getEnumName(MetaframeAction)) {
					//Ignore all these, they do not come from the server
					var en :MetaframeAction = cast action.value;
					trace('Server gets $en');
					switch(en) {
						case RunJob(job, startTime):
							runJob(job);
						default://Ignored
					}
				} else {
					trace('Ignoring client websocket message=${message}');
				}
			default:
				trace('Ignoring client websocket message=${message}');
		}
	}

	function onClose(code :Int, message :Dynamic)
	{
		if (_ws != null) {
			_ws.onmessage = null;
			_ws.onclose = null;
			_ws.close();
			_ws = null;
		}
		if (_stream != null) {
			_stream.end();
			_stream = null;
		}

		if (_activeJobStream != null) {
			_activeJobStream.end();
			_activeJobStream = null;
		}

		if (_finishedJobStream != null) {
			_finishedJobStream.end();
			_finishedJobStream = null;
		}

		_JOB_STREAM = null;
		_activeJobStream = null;
		_finishedJobStream = null;
	}

	function sendMessage(e :EnumValue)
	{
		sendMessageString(WebsocketTools.encodeEnum(e));
	}

	/**
	 * Prefer sendMessage for type checking, but this can be faster
	 * than repeatedly serializing the same message
	 */
	function sendMessageString(m :String)
	{
		if (_ws != null) {
			_ws.send(m);
		} else {
			Log.error('Cannot send action=${m} because WS connection is disposed.');
		}
	}

	@post
	public function postInject()
	{
		// _stream = _JOB_STREAM.then(function(jobStats) {
		// 	if (_ws != null) {
		// 		var action = DashboardAction.SetJobState(jobStats);
		// 		sendMessage(action);
		// 	}
		// });
		// _activeJobStream = _ACTIVE_JOB_STREAM.then(function(jobIds) {
		// 	if (_ws != null) {
		// 		var action = DashboardAction.SetActiveJobs(jobIds);
		// 		sendMessage(action);
		// 	}
		// });
	}
}