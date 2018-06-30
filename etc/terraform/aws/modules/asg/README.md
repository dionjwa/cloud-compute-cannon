#### What is this?

This is the core terraform module for docker-cloud-compute.

It requires:

- redis
- vpc
- s3 config (will not be needed soon)

Optionally:

- fluent for logging

This module cannot be run on its own due to the redis requirement. However, the module `../ccc` provides those needed components if you don't already have them.

#### Terraform notes

There are three auto-scaling groups:

- API servers
- CPU workers
- GPU workers

The workers can *also* provide the API, but it typically makes more sense to separate them so if there are no jobs, only inexpensive servers are running (workers esp GPU workers are expensive).


#### TODO

 - the asg-apu launch config assumes only 1 GPU per machine, but this value must be derived from the AWS instance type.
