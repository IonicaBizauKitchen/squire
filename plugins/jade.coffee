##
## plugins/jade.coffee
## 
## A plugin to handle Jade templates.
##

lib =
	jade:   require "jade"
	squire: require "../squire"
	fs:     require "fs"
	merge:  require "deepmerge"

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["jade"]
	outputExtension: "html"
	
	renderContent: (input, options, callback) ->
		compileFunction = null
		
		try
			compileFunction = lib.jade.compile input, { filename: options.url }
		catch error
			# TODO: Is it possible to get a line number from the error?
			message = error.toString()
			message = "In #{options.url}:\n\n#{message}" if options.url?
			@logError "There was an error while compiling your Jade template.", message
			callback null
			return
		
		locals     = options.locals or {}
		locals.app = @app
		html       = compileFunction locals
		callback html
