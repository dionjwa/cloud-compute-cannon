package ccc;

typedef BatchProcessRequestTurboV2 = {
	@:optional var id :JobId;
	@:optional var inputs :Array<DataBlob>;
	@:optional var image :String;
#if (nodejs && !clientjs)
	@:optional var imagePullOptions :PullImageOptions;
	@:optional var CreateContainerOptions:CreateContainerOptions;
#else
	@:optional var imagePullOptions :Dynamic;
	@:optional var CreateContainerOptions:Dynamic;
#end
	@:optional var command :Array<String>;
	@:optional var workingDir :String;
	@:optional var parameters :JobParams;
	@:optional var inputsPath :String;
	@:optional var outputsPath :String;
	@:optional var meta :Dynamic<String>;
	/* We can save time if outputs are ignored */
	@:optional var ignoreOutputs :Bool;
	/* Often easier if you know the outputs are text files */
	@:optional var forceUtf8Outputs :Bool;
}
