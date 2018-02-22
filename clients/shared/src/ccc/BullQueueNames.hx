package ccc;

@:enum
abstract BullQueueNames(String) from String to String {
	var JobQueue = 'cpu';
	var JobQueueGpu = 'gpu';
	/* Any worker can process this message */
	var SingleMessageQueue = 'single_message_queue';
}
