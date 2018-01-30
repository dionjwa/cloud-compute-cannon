package ccc.metaframe.view;

import router.Link;
import router.RouteComponentProps;

import react.ReactUtil.*;

using StringTools;

enum SizedLayout {
	Tiny;
	Small;
	Medium;
	Big;
}

class AppView
	extends ReactComponentOfPropsAndState<RouteComponentProps, ApplicationState>
	implements IConnectedComponent
{
	static var buttonWidth = 88;
	static var statusWidth = 45;
	static var buttonHeight = 40;
	static var titleHeight = 40;
	static var padding = 5;

	static function getLayoutType(width :Int, height :Int)
	{
		var heightTiny = buttonHeight * 1 + titleHeight + padding;
		var heightSmall = width > buttonWidth * 2 ? heightTiny + buttonHeight + padding : heightTiny + buttonHeight * 2 + padding;
		var heightMedium = heightSmall + buttonHeight + padding;
		var heightMediumNarrow = heightSmall + buttonHeight * 2 + padding;

		var heightLayout = switch(height) {
			case height if (height <= heightTiny):
				SizedLayout.Tiny;
			case height if (height > heightTiny && height <= heightSmall):
				SizedLayout.Small;
			case height if (height > heightSmall && height <= heightMedium):
				SizedLayout.Medium;
			case _:
				SizedLayout.Big;
		}

		//Then take width into account
		return switch(heightLayout) {
			case Tiny: SizedLayout.Tiny;
			case Small:
				width <= buttonWidth + padding ? SizedLayout.Tiny : SizedLayout.Small;
			case Medium:
				switch(width) {
					case width if (width <= buttonWidth):
						SizedLayout.Small;
					default:
						SizedLayout.Medium;
				}
			case Big:
				switch(width) {
					case width if (width > buttonWidth * 2):
						SizedLayout.Big;
					case width if (width <= buttonWidth):
						SizedLayout.Tiny;
					default:
						SizedLayout.Medium;
				}
		}
	}

	public function new(props:RouteComponentProps)
	{
		super(props);
	}

	function mapState(appState:ApplicationState, props:RouteComponentProps)
	{
		return appState;
	}

	function updateDimensions()
	{
        this.setState(copy(state, {height: Browser.window.innerHeight, width: Browser.window.innerWidth}));
    }

    override public function componentWillMount()
    {
        this.updateDimensions();
    }

    override public function componentDidMount()
    {
        Browser.window.addEventListener("resize", this.updateDimensions);
    }

    override public function componentWillUnmount()
    {
        Browser.window.removeEventListener("resize", this.updateDimensions);
    }

	override public function render()
	{
		var jobState :JobState = state.app.jobState;
		var paused = state.app.paused;
		var isProgress = switch(jobState) {
			case Waiting: false;
			case FinishedSuccess: false;
			case FinishedError: false;
			case Cancelled: false;
			case RunningPaused: true;
			case Running: true;
		};

		var dockerImageName :String = state.app != null && state.app.jobImage != null ? state.app.jobImage : null;
		if (dockerImageName != null) {
			dockerImageName = dockerImageName.replace('docker.io/', '');
		}

		var exitCode = state.app != null && state.app.jobResults != null ? '${state.app.jobResults.exitCode}' : '';
		var stdout = state.app != null && state.app.jobResults != null ? state.app.jobResults.stdout : null;
		var stderr = state.app != null && state.app.jobResults != null ? state.app.jobResults.stderr : null;

		var width = state.width;
		var height = state.height;

		var layoutType = getLayoutType(width, height);

		var stdoutContainers = switch(layoutType) {
			case Tiny, Small: null;
			case Medium, Big:
				var isRow = width > (buttonWidth * 2);
				jsx('
					<StdoutContainer stdout={stdout} stderr={stderr} isRow={isRow} windowWidth={width}  />
				');
		}

		var jobDetails = switch(layoutType) {
			case Tiny, Small, Medium: null;
			case Big:
				jsx('
					<Paper id="paper-main" style={{flex:"0 1 auto"}}>
						<ExitCode running=$isProgress exitCode=$exitCode />
					</Paper>
				');
		}

		var status = switch(layoutType) {
			case Tiny:
				jsx('
					<StatusCircle jobState=$jobState />
				');
			case Small, Medium, Big:
				jsx('
					<div id="status-controller" className="app-container-child" >
						<StatusCircle jobState=$jobState />
						<PlayPauseButton paused=$paused />
					</div>
				');
		}

		var styles = {
			expanderHeight: {
				flex: "1 0 auto",
			},
			titleText: {
				fontSize: width > 200 ? "12pt" : "8vw",
			},
		};

		return jsx('
			<div id="app-container">
				<span style={styles.titleText}>
					$dockerImageName
				</span>
				${status}
				${jobDetails}
				<div id="expanderHeight" style={styles.expanderHeight} />
				${stdoutContainers}
			</div>');
	}
}
