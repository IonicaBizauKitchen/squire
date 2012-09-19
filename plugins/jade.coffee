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
		html = null
		
		try
			compileFunction = lib.jade.compile input, { filename: options.url }
			locals          = options?.locals or {}
			locals.app      = @app
			locals.config   = @config
			html            = compileFunction locals
		catch error
			# TODO: Is it possible to get a line number from the error?
			callback null, null, [@createError "There was an error while compiling your Jade template.", error.toString(), options.url]
			return
		
		callback html
	
	renderAppTreeContent: (input, options, callback) ->
		@renderContent input, options, callback
