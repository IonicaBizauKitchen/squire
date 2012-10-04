##
## plugins/css.coffee
## 
## A plugin to support minifying of stylesheets.
##

lib =
	squire: require "../main"
	uglify: require "uglifycss"

class exports.Plugin extends lib.squire.Plugin
	inputExtensions: ["css"]
	outputExtension: "css"
	
	postProcessContent: (css, options, callback) ->
		css = lib.uglify.processString css if @config.minify
		callback css
