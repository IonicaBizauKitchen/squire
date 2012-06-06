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
		global:
			useNib: true
	
	renderContent: (input, options, callback) ->
		renderFunction = lib.stylus input
		renderFunction.use(lib.nib()).import "nib" if @config.useNib
		
		renderFunction.render (error, css) =>
			if error?
				error = @createError "There was an error while compiling your Stylus file.", error.message, options.url
				callback null, null, error
			else
				callback css
