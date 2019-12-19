package ccc.metaframe.view;

import js.npm.reactmarkdown.ReactMarkdown;

import router.RouteComponentProps;

class HelpView
	extends ReactComponentOfProps<Dynamic>
{
	static var CONTENT = util.FileMacro.getFileContent('./clients/metaframe/web/help.md');

	public function new(props:Dynamic)
	{
		super(props);
	}

	override public function render()
	{
		var url = new URL(Browser.window.location.href);
		var template = new haxe.Template(CONTENT);
		var content = template.execute(url);
		return jsx('<div id="HelpView" className="content"><ReactMarkdown source={content} /></div>');
	}
}
