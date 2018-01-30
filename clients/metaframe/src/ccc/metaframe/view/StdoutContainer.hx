package ccc.metaframe.view;

import router.Link;

typedef StdoutContainerProps = {
	var stdout :Array<String>;
	var stderr :Array<String>;
	var isRow :Bool;
	var windowWidth :Float;
	var availableHeight :Float;
}

typedef StdoutContainerState = {
	var open :Bool;
	var toggleIsStdout :Bool;
}

enum StdoutContainerMode {
	ColumnOfButtons;
	RowOfButtons;
	Expanded;
}

class StdoutContainer
	extends ReactComponentOfPropsAndState<StdoutContainerProps,StdoutContainerState>
{
	public function new(props:StdoutContainerProps)
	{
		super(props);
		state = {open:false, toggleIsStdout: true};
	}

	override public function render()
	{
		var isOpen = this.state != null ? this.state.open : false;
		var textLines = props.stdout != null ? props.stdout : props.stderr;

		var isStdErr = props.stderr != null;

		var buttonWidth = 90;
		var buttonHeight = 36;

		var windowWidth = props.windowWidth;
		var availableHeight = props.availableHeight;

		var styles = {
			expandedContainer: {
				height: '${Browser.window.innerHeight}px',
				overflow: "auto",
				display: "flex",
				flexDirection: "column-reverse",
				backgroundColor: "black",
			},
			buttonContainerColumn: {
				fillColor: "blue",
			},
			buttonContainerRow: {
				display: "flex",
				flexDirection: "row",
				justifyContent: "flex-start",
			},
			expanderHeight: {
				flex: "1 0 auto",
				fillColor: "red",
				marginBottom: "auto",
				minHeight: "10px",
				minWidth: "10px",
			},
			fixedHeight: {
				flex: "1 0 auto",
			},
		};

		var mode :StdoutContainerMode =
			if (props.isRow) {
				StdoutContainerMode.RowOfButtons;
			} else {
				StdoutContainerMode.ColumnOfButtons;
			};

		return switch(mode) {
			case ColumnOfButtons:
				jsx('
					<div style={styles.buttonContainerColumn} >
						<div style={styles.expanderHeight} />
						<StdoutFullScreenToggleButton stdout={props.stdout} style={styles.fixedHeight} />
						<StdoutFullScreenToggleButton stderr={props.stderr} style={styles.fixedHeight} />
					</div>
				');
			case RowOfButtons:
				jsx('
					<div style={styles.buttonContainerRow} >
						<StdoutFullScreenToggleButton stdout={props.stdout} style={styles.fixedHeight} />
						<StdoutFullScreenToggleButton stderr={props.stderr} style={styles.fixedHeight} />
					</div>
				');
			case Expanded:
				jsx('
					<div style={styles.expandedContainer} >
						<div style={styles.buttonContainerRow} >
							<StdoutFullScreenToggleButton stdout={props.stdout} style={styles.fixedHeight} />
							<StdoutFullScreenToggleButton stderr={props.stderr} style={styles.fixedHeight} />
						</div>
						<StdoutText text={props.stderr} isStdErr={true} />
						<StdoutText text={props.stdout} isStdErr={false} />
					</div>
				');
		}



		// var textLines = props.stdout != null ? props.stdout : props.stderr;
		// var text = textLines != null ? textLines.join("\n") : null;

		// var isStdErr = props.stderr != null;

		// var buttonText = props.text;

		// var styles = {
		// 	paper: {

		// 	},
		// 	reverseScroll: {
		// 		height: '${Browser.window.innerHeight}px',
		// 		overflow: "auto",
		// 		display: "flex",
		// 		flexDirection: "column-reverse",
		// 		backgroundColor: "black",
		// 	},
		// 	textStyle: {
		// 		color : isStdErr ? "#ff0000" : "#ffffff",
		// 		fontFamily: "monospace"
		// 	},;
		// };

		// return jsx('
		// 	<div >
		// 		<Dialog
		// 			fullScreen={true}
		// 			open={isOpen}
		// 			onClose={this.handleClose}
		// 			>
		// 			<div style={styles.reverseScroll} >
		// 				<Button color="primary" onClick={this.handleClose}>
		// 					Close
		// 				</Button>
		// 				<paper>
		// 					<pre style={styles.textStyle} >
		// 						{text}
		// 					</pre>
		// 				</paper>
		// 			</div>
		// 		</Dialog>
		// 		 <Button raised={true} onClick={this.handleOpen} >
		// 		 	$buttonText
		// 		 </Button>
		// 	</div>
		// ');
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

