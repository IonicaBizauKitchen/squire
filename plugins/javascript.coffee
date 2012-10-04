##
## plugins/javascript.coffee
## 
## A plugin to support minifying of JavaScript files.
##

lib =
	squire: require "../main"
	uglify: require "uglify-js"

class JavaScriptPlugin extends lib.squire.Plugin
	inputExtensions: ["js"]
	outputExtension: "js"
	
	configDefaults:
		global:
			useStrict: false
	
	postProcessContent: (js, options, callback) ->
		errors = null
		
		if @config.minify
			try
				syntaxTree = lib.uglify.parser.parse js
				syntaxTree = lib.uglify.uglify.ast_mangle syntaxTree
				syntaxTree = lib.uglify.uglify.ast_squeeze syntaxTree
				js         = lib.uglify.uglify.gen_code syntaxTree
			catch parseError
				errors = [@createError message: "There was an error while minifying your JavaScript:", details: error.toString(), path: options.path]
		
		if @config.useStrict
			js = "\"use strict\";\n\n#{js}"
		
		if @config.constants?
			constantsString  = ""
			constantsString += "window[\"#{key}\"] = #{JSON.stringify(value)};\n" for key, value of @config.constants
			js               = "#{constantsString}\n#{js}"
		
		callback js, null, errors

# Expose plugin.
exports.Plugin = JavaScriptPlugin
