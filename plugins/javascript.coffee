##
## plugins/javascript.coffee
## 
## A plugin to support minifying of JavaScript files.
##

lib =
	squire: require "../squire"
	uglify: require "uglify-js"

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["js"]
	outputExtension: "js"
	
	postProcessContent: (js, options, callback) ->
		errors = null
		
		if @config.minify
			try
				syntaxTree = lib.uglify.parser.parse js
				syntaxTree = lib.uglify.uglify.ast_mangle syntaxTree
				syntaxTree = lib.uglify.uglify.ast_squeeze syntaxTree
				js         = lib.uglify.uglify.gen_code syntaxTree
			catch parseError
				errors = [@createCoffeeScriptError "There was an error while minifying your JavaScript:", error.toString(), options.url]
		
		callback js, null, errors
