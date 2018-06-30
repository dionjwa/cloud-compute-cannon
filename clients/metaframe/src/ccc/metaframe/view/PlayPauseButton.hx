package ccc.metaframe.view;

import router.Link;

typedef PlayPauseButtonProps = {
	var paused :Bool;
}

typedef PlayPauseButtonState = {}

class PlayPauseButton
	extends ReactComponentOfPropsAndState<PlayPauseButtonProps,PlayPauseButtonState>
	implements redux.react.IConnectedComponent
{
	public function new(props:PlayPauseButtonProps)
	{
		super(props);
		state = {};
	}

	override public function render()
	{
		var icon = this.props.paused ?
			jsx('<span className="icon"><i className="fas fa-pause-circle"></i></span>')
			:
			jsx('<span className="icon"><i className="fas fa-play-circle"></i></span>');

		return jsx('
			<Button
				ref="iconButton"
				onClick={onClick}
			>
				$icon
			</Button>
		');
	}

	function onClick()
	{
		this.dispatch(MetaframeAction.SetPaused(!this.props.paused));
	}
}
