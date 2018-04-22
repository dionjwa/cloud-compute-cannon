import ccc.metaframe.view.AppView;

import ccc.metaframe.ApplicationState;
import ccc.metaframe.ApplicationStore;

import js.Browser;
import js.html.DivElement;
import js.npm.materialui.MaterialUI;
import js.npm.reactrnd.ReactRnD;

import react.ReactDOM;
import react.ReactMacro.jsx;

import redux.Store;
import redux.react.Provider;

import router.Link;
import router.ReactRouter;
import router.RouteComponentProps;

class Main
{
	/**
		Entry point:
		- setup redux store
		- setup react rendering
		- send a few test messages
	**/
	public static function main()
	{
		Webpack.require('./Main.css');
		var store = ApplicationStore.create();
		var root = createRoot();
		render(root, store);

		ApplicationStore.startup(store);
	}

	static function createRoot()
	{
		var root = Browser.document.createDivElement();
		Browser.document.body.appendChild(root);
		return root;
	}

	static function render(root:DivElement, store:Store<ApplicationState>)
	{

		// var theme = Styles.createMuiTheme({
		// 	palette: {
		// 		primary: 'purple',
		// 		secondary: 'green',
		// 		error: 'red',
		// 	},
		// });
		// <MuiThemeProvider theme={} >
		// </MuiThemeProvider>

		// <Rnd default={{
		// 				x: 0,
		// 				y: 0,
		// 				width: 320,
		// 				height: 200,
		// 				disableDragging: false,
		// 				dragAxis: "none"
		// 			}}
		// 			>
		// </Rnd>
		var app = ReactDOM.render(jsx('
			<Provider store=$store>
				<AppView/>
			</Provider>
		'), root);

		#if (debug && react_hot)
		ReactHMR.autoRefresh(app);
		#end
	}

	static function pageWrapper(props:RouteComponentProps)
	{
		var mainDivStyle = {
			height: "100%",
			display: "flex",
			flexDirection: "column",
			minHeight: "100vh"
		}
		return jsx('
			<div style={mainDivStyle}>
				${props.children}
			</div>
		');
	}
}
