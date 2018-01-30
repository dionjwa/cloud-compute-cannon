package ccc.metaframe.view;

import router.Link;

typedef ExitCodeProps = {
	var running :Bool;
	var exitCode :String;
}
class ExitCode
	extends ReactComponentOfProps<ExitCodeProps>
{
	public function new(props:ExitCodeProps)
	{
		super(props);
	}
	override public function render()
	{
		var styles = {
			parent: {
				flex: "0 0 auto",
				display: "flex",
				flexDirection: "row",

			},
		};
		var exitCode = props.exitCode;
		var running = props.running;
		if (exitCode == null || exitCode.length == 0 || running) {
			exitCode = '?';
		}

		var style = {
			color: exitCode == "0" ? "green" : (exitCode == "?" ? "grey" : "red")
		}
		return jsx('
			<div style={styles.parent}>
				<span>Exit Code: ${exitCode}</span>
			</div>
		');
	}
}
