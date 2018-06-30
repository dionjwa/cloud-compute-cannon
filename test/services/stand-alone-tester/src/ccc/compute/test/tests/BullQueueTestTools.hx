package ccc.compute.test.tests;

import js.Error;
import js.npm.bull.Bull;

class BullQueueTestTools
{
	public static function waitUntilQueueEmpty(queue :Queue<Dynamic, Dynamic>) :Promise<Bool>
	{
		var intervalMilliseconds = Ms.parse('50ms');
		var maxAttempts = Math.ceil(Ms.parse('10s') / intervalMilliseconds);
		return RetryPromise.retryRegular(function() {
			return queue.getJobCounts().promhx()
				.then(function(counts :BullJobCounts) {
					if (counts.active > 0 || counts.waiting > 0) {
						throw 'queue not yet empty';
					}
				}).thenTrue();
		}, maxAttempts, intervalMilliseconds);
	}
}
