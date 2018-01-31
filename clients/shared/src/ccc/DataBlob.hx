package ccc;

typedef DataBlob = {
	var value :String;
	var name :String;
	@:optional var source :DataSource; //Default: InputInline
	@:optional var encoding :DataEncoding;
}
