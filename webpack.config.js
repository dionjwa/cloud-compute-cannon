var path = require('path');
var webpack = require('webpack');
var CopyWebpackPlugin = require('copy-webpack-plugin')
var ExtractTextPlugin = require('extract-text-webpack-plugin');

module.exports = {

  devtool: 'cheap-module-eval-source-map',

  entry: [
    // 'react-hot-loader/patch',
    // activate HMR for React

    // bundle the client for webpack-dev-server
    // and connect to the provided endpoint

    // 'webpack/hot/only-dev-server',
    // bundle the client for hot reloading
    // only- means to only hot reload for successful updates

    // the entry point of our app
    './build-metaframe.hxml',

  ],
  devServer: {
    contentBase: './build/clients/metaframe/', // The server will run from this directory
    overlay: true,                  // Show build errors in an overlay
    port: 9091,
    host: "0.0.0.0",
    // hot: true,
    proxy: {
      "/": {
            changeOrigin: true,
            target: "http://localhost:9090"
      }
    },
  },

  output: {
    filename: 'index.js',
    path: path.resolve(__dirname, './build/clients/metaframe/'),
  },

  module: {
    rules: [
      // all files with hxml extension will be handled by `haxe-loader`
      {
        test: /\.hxml$/,
        loader: 'haxe-loader',
        options: {
          debug: true,
          extra: [
          //   "-D react_hot"
          ]
        }
      },
      {
        test: /\.css$/,
        use: [ 'style-loader', 'css-loader' ]
      },
    ]
  },

  plugins: [
    new ExtractTextPlugin('style.css', { allChunks: true }),
    //For copying static web files
    new CopyWebpackPlugin([
      { from: 'clients/metaframe/web/', to: '.' }
    ], {})
  ],
}
