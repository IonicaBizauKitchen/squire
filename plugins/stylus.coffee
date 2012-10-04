##
## plugins/stylus.coffee
## 
## A plugin to handle Stylus stylesheets.
##

lib =
	squire: require "../main"
	stylus: require "stylus"
	nib:    require "nib"
	fs:     require "fs"

class StylusPlugin extends lib.squire.Plugin
	inputExtensions: ["styl"]
	outputExtension: "css"
	
	configDefaults:
		global:
			useNib: true
	
	renderContent: (input, options, callback) ->
		renderFunction = lib.stylus input
		renderFunction.set "filename", options.path if options.path?
		renderFunction.use(lib.nib()).import "nib" if @config.useNib
		
		renderFunction.render (error, css) =>
			if error?
				callback null, null, [@createError message: "There was an error while compiling your Stylus file.", details: error.toString(), path: options.path]
			else
				callback css

# Expose plugin.
exports.Plugin = StylusPlugin
