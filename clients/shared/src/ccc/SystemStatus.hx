package ccc;

import util.TypedDynamicAccess;

#if nodejs
	import js.npm.bull.Bull;
#end

typedef SystemJobStatus = {
	var id :JobId;
	var enqueued :String;
	var started :String;
	var duration :String;
	var definition :BasicBatchProcessRequest;
}

typedef SystemWorkerStatus = {
	var id :MachineId;
	var jobs :Array<SystemJobStatus>;
	var cpus :Int;
	var gpus :Int;
	var disk :Float;
	var status :WorkerStatus;
	var starts :Array<Dynamic>;
	var finished :Int;
	var lastJobTime :Float;
}

typedef SystemStatus = {
#if nodejs
	var queues :TypedDynamicAccess<BullQueueNames,BullJobCounts>;
#else
	var queues :DynamicAccess<Dynamic>;
#end
	var servers :Int;
	var workers :Array<SystemWorkerStatus>;
	var jobs :Array<JobId>;
}

