package ccc;

typedef JobRequestUnified = {
	@:optional var Inputs :Array<DataBlob>;
#if (nodejs && !clientjs)
	@:optional var ImagePullOptions :PullImageOptions;
	@:optional var CreateContainerOptions :CreateContainerOptions;
#else
	@:optional var ImagePullOptions :Dynamic;
	@:optional var CreateContainerOptions :Dynamic;
#end
	@:optional var Parameters :JobParams;
	@:optional var InputsPath :String;
	@:optional var OutputsPath :String;
	@:optional var Meta :Dynamic<String>;
}
