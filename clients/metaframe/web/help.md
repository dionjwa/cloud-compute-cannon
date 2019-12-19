### docker-cloud-compute metaframe

This is a metaframe for running docker containers. On the backend, it will run the docker container with the inputs from upstream metaframes, and return results to its outputs.

Chaining these together, you can create arbitrary, shareable, archivable workflows and applications.

Usage:

    ::href::?image=<YOUR DOCKER IMAGE URL>

E.g.

    ::href::?image=busybox

The image can also be set with the special input field (see below).

There are special inputs you can set to customize the container execution:

- `docker:image` The docker image to run can be in the inputs rather than as a URL parameter (above).
- `docker:command` The shell command as a JSON array of strings (e.g. ["/bin/ls", "."]).
- `docker:ImagePullOptions` A blob of json with [these query parameters](https://docs.docker.com/engine/api/v1.37/#operation/ImageCreate) and/or an [authconfig string](https://www.npmjs.com/package/dockerode#pull-from-private-repos).
- `docker:pause` If this instance is paused (new inputs will not trigger new computes).

Coming soon: parameters for running with available GPUs.
