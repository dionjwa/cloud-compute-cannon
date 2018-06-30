package ccc;

/**
 * I'm expecting this typedef to include:
 * memory contraints
 * CPU/GPU constraints
 * storage constraints
 * These parameters do not count towards checking for a
 * cached job.
 */
typedef JobParams = {
	var maxDuration :Int;//Seconds
	@:optional var cpus :Int; //Default: 1
	@:optional var gpu :Int; //Default: 0
	//Debug/testing flag. It prevents the nvidia
	//docker runtime setting, allowing jobs marked
	//as requiring a GPU to be run on workers that
	//secretly don't have a GPU because who has one anyway
	@:optional var DISABLE_NVIDIA_DOCKER_RUNTIME :Bool;

	/* Job definitions are automatically cached, but
	   parameters (this object) are not part of cache bundle */
	@:optional var DisableCache :Bool;
	/* We can save time if outputs are ignored */
	@:optional var IgnoreOutputs :Bool;
	/* Often easier if you know the outputs are text files */
	@:optional var ForceUtf8Outputs :Bool;

	/* If inputs+outputs are not written to e.g. S3 then
	   then job time is faster. Enable when speed is
	   the priority */
	@:optional var DisablePersistance :Bool;
}