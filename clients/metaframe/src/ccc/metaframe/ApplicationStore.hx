package ccc.metaframe;

import ccc.metaframe.model.AppModel;

import js.react.websocket.WebsocketMiddleware;
import js.react.websocket.WebsocketAction;

import redux.Redux;
import redux.Store;
import redux.StoreBuilder.*;

class ApplicationStore
{
	static var PORT_API :Int
#if debug
		= Std.parseInt(CompileTime.readFile(".env").split('\n').find(function(s) return s.startsWith('PORT_API')).split('=')[1])
#end
	;

	static public function create():Store<ApplicationState>
	{
		// store model, implementing reducer and middleware logic
		var appModel = new AppModel();

		//Get the websocket url. If we're using the react hot-reloader
		//it uses its own websocket, so we need our api websocket on
		//a different port
		var port = Browser.location.port != null ? ":" + Browser.location.port : "";
		if (PORT_API != null) {
			port = ':${PORT_API}';
		}

		var urlParams = new js.html.URLSearchParams(Browser.window.location.search);
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

		var initialState :ApplicationState = {
			app: {
				jobImage: new URL(Browser.window.location.href).searchParams.get('image'),
				metaframeReady: false,
			},
			ws: null,
		};

		return createStore(rootReducer, initialState, middleware);
	}

	static public function startup(store:Store<ApplicationState>)
	{
		// use regular 'store.dispatch' but passing Haxe Enums!
		store.dispatch(WebsocketAction.Connect);
	}
}