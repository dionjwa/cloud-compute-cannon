package ccc.metaframe.view;

import router.Link;

typedef StdoutProps = {
	var stdout :Array<String>;
	var stderr :Array<String>;
}

typedef StdoutState = {
	var open :Bool;
}

class StdoutFullScreenToggleButton
	extends ReactComponentOfPropsAndState<StdoutProps,StdoutState>
{
	public function new(props:StdoutProps)
	{
		super(props);
		state = {open:false};
	}

	override public function render()
	{
		var isOpen = this.state != null ? this.state.open : false;

		var textLines = props.stdout != null ? props.stdout : props.stderr;
		var text = textLines != null ? textLines.join("\n") : null;
		var isStdErr = props.stderr != null;

		var buttonText = isStdErr ? "stderr" : "stdout";

		var styles = {
			reverseScroll: {
				height: '${Browser.window.innerHeight}px',
				overflow: "auto",
				display: "flex",
				flexDirection: "column-reverse",
				backgroundColor: "black",
			},
		}
		return jsx('
			<div className="flex-child">
				<Dialog
					fullScreen={true}
					open={isOpen}
					onClose={this.handleClose}
					>
					<div style={styles.reverseScroll} >
						<Button color="primary" onClick={this.handleClose}>
							Close
						</Button>
						<StdoutText text={text} isStdErr={isStdErr} />
					</div>
				</Dialog>
				 <Button raised={true} onClick={this.handleOpen} >
				 	$buttonText
				 </Button>
			</div>
		');
	}

	function handleOpen()
	{
		this.setState({open:true});
	}

	function handleClose()
	{
		this.setState({open:false});
	}
}

