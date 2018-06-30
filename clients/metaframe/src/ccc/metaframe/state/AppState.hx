package ccc.metaframe.state;

typedef AppState = {
	var jobImage :String;
	var metaframeReady :Bool;
	@:optional var paused :Bool;
	@:optional var jobState :JobState;
	@:optional var jobStartTime :Float;
	@:optional var pendingJob :JobRequestUnified;
	@:optional var pendingJobTime :Float;
	@:optional var jobResults :JobResultsTurboV2;
}