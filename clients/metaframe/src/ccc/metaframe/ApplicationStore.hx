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
		var websocketMiddleware = new WebsocketMiddleware()
			.setSendFilter(appModel.filterActionsToServer)
			.setUrl('/metaframe');

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