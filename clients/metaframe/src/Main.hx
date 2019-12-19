import ccc.metaframe.ApplicationState;
import ccc.metaframe.ApplicationStore;
import ccc.metaframe.view.AppView;

import js.Browser;
import js.html.DivElement;
import js.npm.reactrnd.ReactRnD;

import react.ReactDOM;
import react.ReactMacro.jsx;

import redux.Store;
import redux.react.Provider;

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
		//For markdown generated content, current the Help
		Webpack.require('../../../node_modules/react-bulma-components//dist/react-bulma-components.min.css');
		Webpack.require('../web/css/main.css');
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
		// var app = ReactDOM.render(jsx('
		// 	<Provider store=$store>
		// 		<AppView/>
		// 	</Provider>
		// '), root);
		var app = ReactDOM.render(jsx('
			<Provider store={store}>
				<AppView/>
			</Provider>
		'), root);
		//<Route exact="true" path="/" component={HelpView} />
		//<Router basename="/metaframe">
				// 	<Route path="/:dockerimage" component={AppView} />
				// </Router>
				// /Users/dion/dev/git/docker-cloud-compute/clients/metaframe/src/Main.hx
	}

	static function pageWrapper(props:Dynamic)
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
