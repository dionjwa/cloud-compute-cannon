package ccc.metaframe.state;

enum JobState {
	Waiting;
	Running;
	RunningPaused;
	FinishedSuccess;
	FinishedError;
	Cancelled;
}