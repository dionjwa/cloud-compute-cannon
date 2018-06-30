package ccc.lambda;

@:enum
abstract AsgType(String) from String to String {
	var CPU = 'cpu';
	var GPU = 'gpu';
	var SERVER = 'server';
}