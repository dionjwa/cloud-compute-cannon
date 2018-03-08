# Docker Cloud Compute [![Build Status](https://travis-ci.org/dionjwa/docker-cloud-compute.svg?branch=master)](https://travis-ci.org/dionjwa/docker-cloud-compute)

Docker Image: https://hub.docker.com/r/dionjwa/docker-cloud-compute

## TOC:
 - [AWS INSTALL](etc/terraform/README.md)
 - [LOCAL INSTALL](docs/INSTALL.md)
 - [API](docs/API.md)
 - [ARCHITECTURE](docs/ARCHITECTURE.md)
 - [DEVELOPERS](docs/DEVELOPERS.md)

## Introduction

Docker Cloud Compute (DCC) aims to provide one thing well: a simple API to run docker compute jobs (anywhere).

Features:

- It runs as a docker container, locally on your own machine, or on a scalable pool of workers.
- It can set up GPU-enabled workers (currently AWS only), for example creating ML workflows.
- [Terraform](https://www.terraform.io/intro/index.html) configs allowing you to create (within minutes) your own scalable set of workers in the cloud, and to tear them down when finished.
- Compute jobs results are saved in remote storage (e.g. S3) independent of workers.
- Highly customizable.
- Simple REST API (with Postman examples)

## Example

Install the DCC stack to the cloud, and run some computation jobs, get the results, then destroy the stack.

### 1 Install a stack locally

See [docs/INSTALL.md](docs/INSTALL.md).

### 2 Run a compute job

Get the URL to the API above (either http://localhost:9000 or it will be given by the `terraform apply` command) and run the following job via `cURL`:

```
	curl -X POST \
	  http://localhost:9000/v1 \
	  -H 'Content-Type: application/json' \
	  -d '{
	  "jsonrpc": "2.0",
	  "id": "_",
	  "method": "submitJobJson",
	  "params": {
	    "job": {
	      "wait": true,
	      "image": "busybox:latest",
	      "command": [
	        "ls",
	        "/inputs"
	      ],
	      "inputs": [
	        {
	          "name": "inputFile1",
	          "value": "foo"
	        },
	        {
	          "name": "inputFile2",
	          "value": "bar"
	        }
	      ],
	      "parameters": {
	        "maxDuration": 600000,
	        "cpus": 1
	      }
	    }
	  }
	}'
```

This simply prints the input files to `stdout`. Nothing special, except you can run any docker image you want to do pretty much anything.

## ROADMAP

See [docs/ROADMAP.md](docs/ROADMAP.md).

## License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
