package ccc.compute.server.services.queue;

import js.npm.bull.Bull;
import ccc.QueueJobDefinition;
import ccc.compute.worker.QueueJobResults;

class Queues
{
	public var cpu :Queue<QueueJobDefinition, QueueJobResults>;
	public var gpu :Queue<QueueJobDefinition, QueueJobResults>;

	public function new(cpu :Queue<QueueJobDefinition, QueueJobResults>, gpu :Queue<QueueJobDefinition, QueueJobResults>)
	{
		this.cpu = cpu;
		this.gpu = gpu;
	}
}