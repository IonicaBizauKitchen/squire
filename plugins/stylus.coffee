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

class exports.Plugin extends lib.squire.BasePlugin
	inputExtensions: ["styl"]
	outputExtension: "css"
	
	defaultConfig:
		useNib: true
	
	buildFile: (inputUrl, outputUrl, callback) ->
		renderFunction = lib.stylus lib.fs.readFileSync(inputUrl).toString()
		renderFunction.use(lib.nib()).import "nib" if @config.useNib
		
		renderFunction.render (error, css) =>
			if error?
				@logError "There was an error while compiling your Stylus file.", "In #{inputUrl}:\n\n#{error.message}"
			else
				lib.fs.writeFileSync outputUrl, css
			
			callback()
