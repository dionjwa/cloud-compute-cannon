package ccc.metaframe.action;

import ccc.metaframe.state.*;

enum MetaframeAction
{
	SetPaused(paused :Bool);
	SetJobResults(result :JobResultsTurboV2);
	RunJob(job :JobRequestUnified, startTime :Float);
	PendingJob(job :JobRequestUnified);
}
