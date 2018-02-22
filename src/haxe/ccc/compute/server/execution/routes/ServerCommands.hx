package ccc.compute.server.execution.routes;

import haxe.Resource;

import js.npm.redis.RedisClient;
import js.npm.docker.Docker;
import t9.redis.RedisLuaTools;

import util.DockerTools;
import util.DockerUrl;
import util.DockerRegistryTools;
import util.DateFormatTools;

/**
 * Server API methods
 */
class ServerCommands
{
	/** For debugging */
	public static function traceStatus(injector :Injector) :Promise<Bool>
	{
		return ccc.compute.server.services.status.SystemStatusManager.getStatus(injector)
			.then(function(statusBlob) {
				traceMagenta(Json.stringify(statusBlob, null, "  "));
				return true;
			});
	}

	/** For debugging */
	// public static function getWorkerStatus(injector :Injector) :Promise<WorkerStatus>
	// {
	// 	var redis :RedisClient = injector.getValue(RedisClient);

	// 	var internalState :WorkerStateInternal = injector.getValue('ccc.WorkerStateInternal');

	// 	var result :WorkerStatus = {
	// 		id: internalState.id,
	// 		cpus: internalState.ncpus,
	// 		jobs: [],
	// 		healthStatus: internalState.health,
	// 		timeLastHealthCheck: internalState.timeLastHealthCheck != null ? internalState.timeLastHealthCheck.toString() : null
	// 	};
	// 	return Jobs.getJobsOnWorker(internalState.id)
	// 		.pipe(function(jobList) {
	// 			return Promise.whenAll(jobList.map(function(jobId) {
	// 				return JobStatsTools.get(jobId);
	// 			}))
	// 			.then(function(jobDatas) {
	// 				result.jobs = jobDatas;
	// 				return true;
	// 			});
	// 		})
	// 		.pipe(function(_) {
	// 			var workerCache :WorkerCache = redis;
	// 			return workerCache.getHealthStatus(internalState.id)
	// 				.then(function(status) {
	// 					result.healthStatus = status;
	// 				});
	// 		})
	// 		.then(function(_) {
	// 			return result;
	// 		});
	// }

	// public static function status() :Promise<SystemStatus>
	// {
	// 	return ccc.compute.server.services.status.SystemStatusManager.getStatus(_injector);
	// }

	public static function version() :ServerVersionBlob
	{
		if (_versionBlob == null) {
			_versionBlob = versionInternal();
		}
		return _versionBlob;
	}

	static var _versionBlob :ServerVersionBlob;
	static function versionInternal() :ServerVersionBlob
	{
		var date = util.MacroUtils.compilationTime();
		var haxeCompilerVersion = Version.getHaxeCompilerVersion();
		var customVersion = null;
		try {
			customVersion = Fs.readFileSync('VERSION', {encoding:'utf8'}).trim();
		} catch(ignored :Dynamic) {
			customVersion = null;
		}
		var npmPackageVersion = null;
		try {
			npmPackageVersion = Json.parse(Resource.getString('package.json')).version;
		} catch(e :Dynamic) {}
		var gitSha = null;
		try {
			gitSha = Version.getGitCommitHash().substr(0,8);
		} catch(e :Dynamic) {}

		//Single per instance id.
		var instanceVersion :String = null;
		try {
			instanceVersion = Fs.readFileSync('INSTANCE_VERSION', {encoding:'utf8'});
		} catch(ignored :Dynamic) {
			instanceVersion = js.npm.shortid.ShortId.generate();
			Fs.writeFileSync('INSTANCE_VERSION', instanceVersion, {encoding:'utf8'});
		}

		var blob :ServerVersionBlob = {
			npm: npmPackageVersion,
			git: gitSha,
			compiler: haxeCompilerVersion,
			VERSION: customVersion,
			instance: instanceVersion,
			compile_time: date
		};

		return blob;
	}
}