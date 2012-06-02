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
		try
			compileFunction = lib.jade.compile input, { filename: options.url }
			locals          = options.locals or {}
			locals.content  = @appContent
			html            = compileFunction locals
			callback html
		catch error
			throw error
			# TODO: The error we get back is not very helpful (no context information). Can we get
			# the line number or any other useful information?
			message = error.toString()
			message = "In #{options.url}:\n\n#{message}" if options.url?
			@logError "There was an error while compiling your Jade template.", message
			callback null
