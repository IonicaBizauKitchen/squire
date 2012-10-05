##
## plugins/jade.coffee
## 
## A plugin to handle Jade templates.
##

lib =
	squire: require "../main"
	jade:   require "jade"
	fs:     require "fs"
	merge:  require "deepmerge"

class JadePlugin extends lib.squire.Plugin
	inputExtensions: ["jade"]
	outputExtension: "html"
	
	renderContent: (input, options, callback) ->
		html = null
		
		try
			compileFunction = lib.jade.compile input, { filename: options.path }
			locals          = options?.locals or {}
			locals.app      = @app
			locals.config   = @config
			html            = compileFunction locals
		catch error
			callback null, null, [@createError message: "There was an error while compiling your Jade template.", details: error.toString(), path: options.path]
			return
		
		callback html
	
	renderAppTreeContent: (input, options, callback) ->
		@renderContent input, options, callback

# Expose plugin.
exports.Plugin = JadePlugin
