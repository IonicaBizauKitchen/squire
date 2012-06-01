##
## plugins/markdown.coffee
## 
## A plugin to handle Markdown files.
##

lib =
	markdown: require("markdown-js").markdown
	squire:   require "../squire"
	fs:       require "fs"

class exports.Plugin extends lib.squire.BasePlugin
	inputExtensions: ["md", "markdown"]
	outputExtension: "html"
	
	buildFile: (inputUrl, outputUrl, callback) ->
		html = lib.markdown lib.fs.readFileSync(inputUrl).toString()
		lib.fs.writeFileSync outputUrl, html
		callback()
	
	# TODO
	# buildIndexFile: (inputUrl, outputUrl, callback) ->
