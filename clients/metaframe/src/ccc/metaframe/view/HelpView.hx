package ccc.metaframe.view;

import router.Link;
import router.RouteComponentProps;

import react.ReactUtil.*;

class HelpView
	extends ReactComponentOfProps<RouteComponentProps>
{
	public function new(props:RouteComponentProps)
	{
		super(props);
	}

	override public function render()
	{
		return jsx('
			<div id="app-container">
				<span>
					You need to add the docker image
				</span>
			</div>');
	}
}
