##
## plugins/squire.coffee
## 
## A plugin to handle Stylus stylesheets.
##

lib =
	stylus: require "stylus"
	nib:    require "nib"
	squire: require "../squire"
	fs:     require "fs"

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["styl"]
	outputExtension: "css"
	
	configDefaults:
		useNib: true
	
	renderContent: (input, options, callback) ->
		renderFunction = lib.stylus input
		renderFunction.use(lib.nib()).import "nib" if @config.useNib
		
		renderFunction.render (error, css) =>
			if error?
				message = error.message
				message = "In #{options.url}:\n\n#{message}" if options.url?
				@logError "There was an error while compiling your Stylus file.", message
				callback null
			else
				callback css
