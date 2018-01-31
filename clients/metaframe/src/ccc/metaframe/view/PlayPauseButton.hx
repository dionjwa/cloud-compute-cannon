package ccc.metaframe.view;

import router.Link;

typedef PlayPauseButtonProps = {
	var paused :Bool;
}

typedef PlayPauseButtonState = {}

class PlayPauseButton
	extends ReactComponentOfPropsAndState<PlayPauseButtonProps,PlayPauseButtonState>
	implements IConnectedComponent
{
	public function new(props:PlayPauseButtonProps)
	{
		super(props);
		state = {};
	}

	override public function render()
	{
		return jsx('
			<Button
				ref="iconButton"
				raised={true}
				onClick={onClick}
			>
				<Icon>${this.props.paused ? "pause" : "play_arrow"}</Icon>
			</Button>
		');
	}

	function onClick()
	{
		this.dispatch(MetaframeAction.SetPaused(!this.props.paused));
	}
}

