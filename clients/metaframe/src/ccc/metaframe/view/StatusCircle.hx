package ccc.metaframe.view;

import router.Link;

typedef StatusCircleProps = {
	var jobState :JobState;
}

class StatusCircle
	extends ReactComponentOfProps<StatusCircleProps>
{
	public function new(props:StatusCircleProps)
	{
		super(props);
	}

	override public function render()
	{
		var jobState = this.props.jobState == null ? JobState.Waiting : this.props.jobState;

		var color = switch(jobState) {
			case Waiting: 'grey';
			case Running,RunningPaused: 'blue';
			case FinishedSuccess: 'green';
			case FinishedError,Cancelled: 'red';
		}

		switch(jobState) {
			case Waiting,Running,RunningPaused:
				return jsx('
					<div className="status-svg">
						<CircularProgress size={38} style={{ color: "$color" }} />
					</div>
				');
			case FinishedSuccess:
				return jsx('<Icon className="status-svg" style={{ fontSize: 38, color: "$color" }} >done</Icon>');
			case FinishedError,Cancelled:
				return jsx('<Icon className="status-svg" style={{ fontSize: 38, color: "$color" }} >error</Icon>');
		}
	}
}
