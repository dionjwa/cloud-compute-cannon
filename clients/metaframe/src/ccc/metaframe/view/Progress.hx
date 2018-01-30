package ccc.metaframe.view;

import router.Link;

typedef ProgressProps = {
	var running :Bool;
}
class Progress
	extends ReactComponentOfProps<ProgressProps>
{
	public function new(props:ProgressProps)
	{
		super(props);
	}
	override public function render()
	{
		var styles = {
			parent: {
				flex: "1 0 auto",
				display: "flex",
				flexDirection: "row",
				minHeight: "6px",
				maxHeight: "6px",
				height: "6px",
				padding: "2px",
			},
		};
		return this.props.running ?
			jsx('<LinearProgress style={styles.parent} mode="indeterminate"/>')
			:
			jsx('<div style={styles.parent} />');
	}
}

