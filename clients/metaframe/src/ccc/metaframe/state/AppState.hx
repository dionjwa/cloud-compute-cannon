package ccc.metaframe.state;

typedef AppState = {
	var jobState :JobState;
	var paused :Bool;
	@:optional var jobStartTime :Float;
	@:optional var jobImage :String;
	@:optional var pendingJob :JobRequestUnified;
	@:optional var pendingJobTime :Float;
	@:optional var jobResults :JobResultsTurboV2;
}