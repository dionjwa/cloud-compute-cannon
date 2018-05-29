package ccc.metaframe;

import ccc.metaframe.model.AppModel;

import js.react.websocket.WebsocketMiddleware;
import js.react.websocket.WebsocketAction;

import redux.Redux;
import redux.Store;
import redux.StoreBuilder.*;

class ApplicationStore
{
	static public function create():Store<ApplicationState>
	{
		// store model, implementing reducer and middleware logic
		var appModel = new AppModel();

		//Get the websocket url. If we're using the react hot-reloader
		//it uses its own websocket, so we need our api websocket on
		//a different port
		var port = Browser.location.port != null ? ":" + Browser.location.port : "";
		// if (port == ':8090') {
		// 	port = ':8000';
		// }

		var urlParams = new js.html.URLSearchParams(Browser.window.location.search);

		var queryParamWsPort :String = urlParams.has('WSPORT') ? urlParams.get('WSPORT') : urlParams.get('wsport');
		if (queryParamWsPort != null) {
			try {
				port = ':${queryParamWsPort}';
				trace('CUSTOM WS PORT=${queryParamWsPort}');
			} catch(e :Dynamic) {
				//Ignored
			}
		}
		var protocol = Browser.location.protocol == "https:" ? "wss:" : "ws:";
		var wsUrl = '${protocol}//${Browser.location.hostname}${port}/metaframe';

		var websocketMiddleware = new WebsocketMiddleware()
			.setSendFilter(appModel.filterActionsToServer)
			.setUrl(wsUrl);

		// create root reducer normally, excepted you must use
		// 'StoreBuilder.mapReducer' to wrap the Enum-based reducer
		var rootReducer = Redux.combineReducers({
			app: mapReducer(MetaframeAction, appModel),
			ws: mapReducer(WebsocketAction, websocketMiddleware),
		});

		// create middleware normally, excepted you must use
		// 'StoreBuilder.mapMiddleware' to wrap the Enum-based middleware
		var middleware = Redux.applyMiddleware(
			appModel.createMiddleware(),
			websocketMiddleware.createMiddleware()
			// ,js.npm.reduxlogger.ReduxLogger.createLogger(
			// 	{
			// 		actionTransformer: function(action :{type:EnumValue,value:Dynamic}) {
			// 			var blob = {type:'${action.type}.${Type.enumConstructor(action.value)}', value:action.value};
			// 			return blob;
			// 		}
			// 	})
		);

		// user 'StoreBuilder.createStore' helper to automatically wire
		// the Redux devtools browser extension:
		// https://github.com/zalmoxisus/redux-devtools-extension
		return createStore(rootReducer, null, middleware);
	}

	static public function startup(store:Store<ApplicationState>)
	{
		// use regular 'store.dispatch' but passing Haxe Enums!
		store.dispatch(WebsocketAction.Connect);
	}
}