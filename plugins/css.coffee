##
## plugins/css.coffee
## 
## A plugin to support minifying of stylesheets.
##

lib =
	uglify: require "uglifycss"
	squire: require "../squire"

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["css"]
	outputExtension: "css"
	
	postProcessContent: (css, options, callback) ->
		css = lib.uglify.processString css if @config.minify
		callback css
