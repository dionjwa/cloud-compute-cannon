package ccc;

typedef WorkerStateInternal = {
	var ncpus :Int;
	var ngpus :Int;
	var health :WorkerHealthStatus;
	var timeLastHealthCheck :Date;
	var jobs :Array<JobId>;
	var id :MachineId;
}
