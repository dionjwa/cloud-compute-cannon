package ccc;

@:enum
abstract BullQueueSingleMessageQueueType(String) from String to String {
	var log = 'log';
	/**
	 * Jobs can be removed via an API call or via automatic cleanup
	 * a) API call: immediately puts jobRemoval job on this queue.
	 *    Then proceeds to do the removal. Putting it on the queue
	 *    means that if large files are being deleted, but this process
	 *    dies, the job cleanup will be picked up by another process.
	 *    This could result in multiple executions of job removal. This
	 *    is totally ok, removal calls are idempotent safe to run
	 *    concurrently.
	 * b) Automatic cleaning: puts a removal job below on the queues.
	 */
	var jobRemoval = 'jobRemoval';
}
