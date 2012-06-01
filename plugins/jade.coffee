##
## plugins/jade.coffee
## 
## A plugin to handle Jade templates.
##

lib =
	jade:   require "jade"
	squire: require "../squire"
	fs:     require "fs"

class exports.Plugin extends lib.squire.BasePlugin
	inputExtensions: ["jade"]
	outputExtension: "html"
	
	buildFile: (inputUrl, outputUrl, callback) ->
		jade = lib.fs.readFileSync(inputUrl).toString()
		
		try
			compileFunction = lib.jade.compile jade, { filename: inputUrl }
			html            = compileFunction { content: @appContent }
			lib.fs.writeFileSync outputUrl, html
		catch error
			# TODO: The error we get back is not very helpful (no context information). Can we get
			# the line number or any other useful information?
			@logError "There was an error while compiling your Jade template.", "In #{inputUrl}:\n\n#{error.toString()}"
		
		callback()
