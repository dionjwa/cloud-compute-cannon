//
// npm dependencies library
//
(function(scope) {
	'use-strict';
	scope.__registry__ = Object.assign({}, scope.__registry__, {

		// list npm modules required in Haxe

		'react': require('react'),
		'prop-types': require('prop-types'),
		'react-dom': require('react-dom'),
		'redux': require('redux'),
		'redux-logger': require('redux-logger'),
		'material-ui': require('material-ui'),
		'material-ui-icons': require('material-ui-icons'),
		'material-ui/styles/withTheme': require('material-ui/styles/withTheme'),
		'material-ui/styles/createMuiTheme': require('material-ui/styles/createMuiTheme'),
		'material-ui/styles/withStyles': require('material-ui/styles/withStyles'),
		'material-ui/Progress': require('material-ui/Progress'),
		'react-rnd': require('react-rnd'),

	});

	if (process.env.NODE_ENV !== 'production' && process.env.TRAVIS !== '1') {
		// enable hot-reload
		require('haxe-modular');
	}

})(typeof $hx_scope != "undefined" ? $hx_scope : $hx_scope = {});
