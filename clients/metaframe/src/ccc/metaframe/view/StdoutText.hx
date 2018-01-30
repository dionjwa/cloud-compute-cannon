package ccc.metaframe.view;

import router.Link;

typedef StdoutTextProps = {
	var text :Array<String>;
	var isStdErr :Bool;
}

class StdoutText
	extends ReactComponentOfProps<StdoutTextProps>
{
	public function new(props:StdoutTextProps)
	{
		super(props);
	}

	override public function render()
	{
		var text = props.text;
		var isStdErr = props.isStdErr;

		var styles = {
			paper: {

			},
			text: {
				color : isStdErr ? "#ff0000" : "#ffffff",
				fontFamily: "monospace",
				overflowWrap: "break-word",
			},
		}
		return jsx('
			<paper style={styles.paper}>
				<span style={styles.text} >
					{text}
				</span>
			</paper>
		');
	}
}

