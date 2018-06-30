# Architecture and application design

![Docker Cloud Compute Architecture](images/architecture1.png)


Walkthrough:

API request [[1]](#1-api-gateway) arrives.  The request is passed to one of the servers [[2]](#2-api-request-servers). Assuming the request is a job submission, the job is registered with the redis db [[3]](#3-redis-database), and the inputs are copied to external storage [[4]](#4-external-storage)<sup>[[&ast;]](#persisted-and-fast-jobs)</sup>, and the job is then put on the queue. A worker [[5]](#5-workers) will then take the job off the queue, create a docker container to run the job, copy inputs<sup>[[&ast;]](#persisted-and-fast-jobs)</sup>, execute the container. When the job is finished, outputs<sup>[[&ast;]](#persisted-and-fast-jobs)</sup> are copied to external storage [[4]](#4-external-storage), and the job is finished and removed from the queue.

In the background, a lambda function [[6]](#6-scaling-lambda) monitor the workers and the queue, and will scale up/down as appropriate.

## 1. API Gateway

The DCC stack does not have any access control itself, so it is the responsibility of the person deploying DCC to control access.

## 2. API request servers

By default, there is no difference between servers that process API requests, and workers that process jobs, the same server process handles both.

However, if the env var `DISABLE_WORKER=true` is passed to the server process, then processing jobs is disabled. This reduces the attack surface of the stack as the docker daemon is not mounted by servers. Servers and workers do not interact directly, they both communicate via [redis](#3-redis-database).

This would mean you need auto-scaling groups: one for the servers, and one for the workers:

![Docker Cloud Compute Architecture](images/architecture2.png)

### Persisted and fast jobs

There are two types of jobs

 1. Standard jobs, where inputs and outputs are copied to external storage. These jobs can be long running. A submission request is returned immediately with the job id, this is used to query the job status via HTTP requests or a websocket.
 2. Fast jobs. External storage is ignored, inputs are copied into Redis (so cannot be huge), and the jobs are ahead of standard jobs in the queue. The request response is returned when the job is complete. Since there is no durability of inputs/outputs, if a job fails, the querying application should retry.


## 3. Redis database

Stores:

	- queues
	- jobs
	- job inputs/outputs
	- worker health status
	- job statistics

It contains the state of the application, and if it goes down, the stack will not work.

## 4. External storage

E.g. S3. Job inputs and outputs are stored here.

## 5. Workers

A worker consists of simply a machine with docker installed. The worker process runs as a privileged docker container that listens to the redis queue. When a job is taken off the queue, a container is spun up, inputs copied, docker container is executed, outputs copied, and the queue is notified the job is complete.

## 6. Scaling lambda

Because the Autoscaling group control of scaling lacks the ability to look at the redis queue, an AWS lambda periodically checks the redis queue, and adjust workers up or down depending on various factors (queue size/state, time workers have been up, worker health, last time scaled down).

The lambda also checks the worker health, by checking the redis db for a key that matches the worker. Workers periodically update this key with their health status. If the key is missing, or the value is not 'HEALTHY' then the worker is terminated. If the autoscaling group (ASG) minimum is not fulfilled, the ASG will create a fresh worker.

Scale up checks occur frequently (1/minute) so the stack is responsive, scale down occurs less frequently (every 15/30m). Both are configurable.

## GPU support

DCC has support for running jobs in workers with GPUS.

**Prerequisites:**

Terraform:

 - terraform module `etc/terraform/aws/modules/asg` variables:
   - `workers_gpu_max` must be > 0.
   - `instance_type_gpu` must be an appropriate instance (the default is ok). WARNING: see limitations below about using instances with GPUs > 1.
   - `region` must be one that supports GPU instances (not all do)
   - `server_version` must be `>= 0.5.0`.

Limitations:

 - Workers cannot currently determine how many GPUs they have, and this value is currently hard-coded to be 1. This is a relatively easy parameter to address via mapping AWS instance types to GPUs, however I would prefer this value be determined at startup time.
 - Worker startup time is really slow and can be improved.

**API:**

Add `gpu:1` to the `parameters` field for job descriptions e.g.:

```
{
	...
	"image": "docker.io/busybox:latest",
	"parameters": {
		"gpu": 1,
	},
	...
}
```

**Code:**

There are two main job queues, 'cpu' and 'gpu', and a job can only be on one. When a worker connects to redis, it will process concurrent jobs from each of those queues up to the number of corresponding cpu/gpus. Apart from the labels, the queues function identically, the ingest and output the same types.

Since it also requires a CPU to run a GPU job, the overall number of concurrent **CPU** jobs a GPU machine can process is CPUs - GPUs. If there are remaining CPUs, those will be used for the CPU queue, meaning a GPU machine can process from both the CPU and the GPU queue (concurrently). Reducing the CPUs for the GPU jobs may not be strictly needed, perhaps the GPU usage means the CPU is idle. TDB with CPU profiling (`Queuejobs.postInject()`).

Data flow:

1. A job is posted to the API, eventually the job request ends up at `QueueTools.addJobToQueue` where it is put in the cpu or gpu queue.
2. `QueueJobs` will eventually consume the GPU job.
3. Workers consuming a `gpu` queue will process the job exactly the same as a `cpu` job.
4. When the job is being executed on the worker, some extra docker config is added to use the nvidia runtime:

```
if (job.parameters.gpu > 0 && !job.parameters.DISABLE_NVIDIA_DOCKER_RUNTIME && !ServerConfig.DISABLE_NVIDIA_RUNTIME) {
	Reflect.setField(opts.HostConfig, "Runtime", "nvidia");
}
```


**Testing:**

There are tests to validate the correct data flow of CPU/GPU jobs going to correct workers. However actual GPU testing requires deployment to the cloud, so is less structured. There are some paths to quickly test CPU/GPU jobs (in `ServerPaths.hx`):

 - `/test/cpu`
 - `/test/cpu/<count>/<seconds-delay>`
 - `/test/gpu`
 - `/test/gpu/<count>/<seconds-delay>`

I have also used this mxnet image for testing the GPU as written in their docs:

https://github.com/apache/incubator-mxnet/tree/master/docker



