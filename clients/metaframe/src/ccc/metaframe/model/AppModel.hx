package ccc.metaframe.model;

import metapage.*;
// import metapage.PipeUpdateBlob;

import redux.Redux;

class AppModel
	implements IReducer<MetaframeAction, AppState>
{
	public var initState :AppState = {
		paused: false,
		jobState:JobState.Waiting
	};

	public var store :StoreMethods<ApplicationState>;

	var _metaframe :Metaframe;

	public function new()
	{
		initializeMetaframe();
	}

	public function filterActionsToServer(action :Action) :Bool
	{
		if (Type.getEnumName(MetaframeAction) == action.type) {
			var e :MetaframeAction = cast action.value;
			switch(e) {
				case RunJob(job, time): return true;
				default:
			}
		}
		return false;
	}

	function initializeMetaframe()
	{
		_metaframe = new Metaframe({debug:false});
		_metaframe.onInputs(onInputs);
	}

	function onInputs(inputs :Array<PipeUpdateClientV1>)
	{
		var jobRequest :JobRequestUnified = {
			Inputs: [],
			CreateContainerOptions: {
				Image: null
			},
		};

		function maybeParseJson(value :Dynamic) :Dynamic {
			if (untyped __typeof__(value) == 'string') {
				try {
					return Json.parse(value);
				} catch (err :Dynamic) {
					trace(err);
					return value;
				}
			} else {
				return value;
			}
		}

		//Massage inputs
		if (inputs != null) {
			for (input in inputs) {
				switch(input.name) {
					case 'docker:ImagePullOptions':
						if (input.value != null && input.value != '') {
							jobRequest.ImagePullOptions = maybeParseJson(input.value);
						} else {
							jobRequest.ImagePullOptions = null;
						}
					case 'docker:CreateContainerOptions':
						if (input.value != null && input.value != '') {
							jobRequest.CreateContainerOptions = maybeParseJson(input.value);
						} else {
							jobRequest.CreateContainerOptions = null;
						}
					case 'docker:Parameters':
						if (input.value != null && input.value != '') {
							jobRequest.Parameters = maybeParseJson(input.value);
						} else {
							jobRequest.Parameters = null;
						}
					case 'docker:InputsPath':
						jobRequest.InputsPath = input.value;
					case 'docker:OutputsPath':
						jobRequest.OutputsPath = input.value;
					case 'docker:Meta':
						if (input.value != null && input.value != '') {
							jobRequest.Meta = maybeParseJson(input.value);
						} else {
							jobRequest.Meta = null;
						}
					case 'docker:image':
						if (input.value != null && input.value != '') {
							try {
								jobRequest.CreateContainerOptions.Image = input.value;
							} catch (err :Dynamic) {
								trace(err);
							}
						}
					case 'docker:command':
						if (input.value != null && input.value != '') {
							jobRequest.CreateContainerOptions.Cmd = maybeParseJson(input.value);
						}
					default:
						jobRequest.Inputs.push({
							name: input.name,
							value: input.value,
							encoding: cast input.encoding
						});
				}
			}
		}

		if (store.getState().app.paused) {
			store.dispatch(MetaframeAction.PendingJob(jobRequest));
		} else {
			store.dispatch(MetaframeAction.RunJob(jobRequest, Date.now().getTime()));
		}
	}

	/* SERVICE */

	public function reduce(state :AppState, action :MetaframeAction) :AppState
	{
		return switch(action)
		{
			case SetJobResults(results):
				var newState :AppState = copy(state, {
					lastJobDuration: Date.now().getTime() - state.jobStartTime,
					jobResults: results,
					jobState: results.exitCode == 0 ? JobState.FinishedSuccess : JobState.FinishedError,
				});
				newState;
			case SetPaused(paused):
				copy(state, {
					jobState: switch(state.jobState) {
						case Waiting: JobState.Waiting;
						case Running: paused ? JobState.RunningPaused : JobState.Running;
						case RunningPaused: paused ? JobState.RunningPaused : JobState.Running;
						case FinishedSuccess: JobState.FinishedSuccess;
						case FinishedError: JobState.FinishedError;
						case Cancelled:  JobState.Cancelled;
					},
					paused: paused
				});
			case RunJob(job, startTime):
				copy(state, {
					paused: false,
					jobImage: job.CreateContainerOptions.Image,
					jobStartTime: startTime,
					jobState: JobState.Running,
					pendingJob: null
				});
			case PendingJob(job):
				copy(state, {
					jobImage: job.CreateContainerOptions.Image,
					pendingJob: job,
					pendingJobTime: Date.now().getTime(),
				});
		}
	}

	/* MIDDLEWARE */

	/**
	 * For now, this is just grabbing the store.
	 * Surely there is a better way to do this.
	 * @return [description]
	 */
	public function createMiddleware()
	{
		return function (store:StoreMethods<ApplicationState>) {
			this.store = store;
			return function (next:Dispatch):Dynamic {
				return function (action:Action):Dynamic {
					if (action == null) {
						throw 'action == null';
					}
					if (action.type == null) {
						throw 'action.type == null, action=${action}';
					}
					if (Type.getEnumName(MetaframeAction) == action.type) {
						var e :MetaframeAction = cast action.value;
						switch(e) {
							//If unpausing, fire off any pending job
							case SetPaused(paused):
								if (!paused && store.getState().app.pendingJob != null)
								{
									var replacement = MetaframeAction.RunJob(store.getState().app.pendingJob, Date.now().getTime());
									action.type = Type.getEnumName(Type.getEnum(replacement));
									action.value = replacement;
								}
							case PendingJob(job): //Ignore
							case RunJob(job, startTime): //Ignore
							case SetJobResults(result):
								//Set the metaframe outputs
								if (result != null) {
									var outputs :Array<PipeUpdateBlob> = [];
									outputs.push({
										name: 'docker:exitCode',
										value: result.exitCode,
									});
									outputs.push({
										name: 'docker:stderr',
										value: result.stderr != null ? result.stderr.join('') : '',
									});
									outputs.push({
										name: 'docker:stdout',
										value: result.stdout != null ? result.stdout.join('') : '',
									});
									outputs.push({
										name: 'docker:error',
										value: result.error,
									});
									if (result.outputs != null) {
										for (o in result.outputs) {
											outputs.push({
												name: cast o.name,
												value: cast o.value,
												encoding: cast o.encoding,
												source: cast o.source,
											});
										}
									}

									_metaframe.setOutputs(outputs);
								}
						}
					}

					return next(action);
				}
			}
		}
	}
}
