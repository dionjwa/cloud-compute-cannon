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

	/* Job definitions are automatically cached, but
	   parameters (this object) are not part of cachen bundle */
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