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
			case Running,RunningPaused: 'yellow';
			case FinishedSuccess: 'green';
			case FinishedError,Cancelled: 'red';
		}
		return jsx('<span className="icon"><i className="fas fa-circle" style={{ color: "$color" }} ></i></span>');
	}
}
