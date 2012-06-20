##
## plugins/squire.coffee
## 
## A plugin to handle Stylus stylesheets.
##

lib =
	stylus: require "stylus"
	nib:    require "nib"
	squire: require "../squire"
	uglify: require "uglifycss"
	fs:     require "fs"

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["styl"]
	outputExtension: "css"
	
	configDefaults:
		global:
			useNib: true
	
	renderContent: (input, options, callback) ->
		renderFunction = lib.stylus input
		renderFunction.set "filename", options.url if options.url
		renderFunction.use(lib.nib()).import "nib" if @config.useNib
		
		renderFunction.render (error, css) =>
			if error?
				callback null, null, [@createError "There was an error while compiling your Stylus file.", error.toString(), options.url]
			else
				callback if @config.minify then lib.uglify.processString(css) else css
