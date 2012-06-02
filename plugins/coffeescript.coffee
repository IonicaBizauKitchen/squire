##
## plugins/coffeescript.coffee
## 
## A plugin to handle CoffeeScript files.
##

lib =
	fs:     require "fs"
	squire: require "../squire"
	coffee: require "coffee-script"

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["coffee"]
	outputExtension: "js"
	
	renderContent: (input, options, callback) ->
		js = null
		
		try
			js = lib.coffee.compile input, options.compilerOptions or {}
		catch error
			@logError "There was an error while compiling your CoffeeScript:", error.toString().split("\n")[0]
		
		callback js
	
	renderContentList: (inputs, options, callback) ->
		# We first need to check for syntax errors. We have to do this as a separate step because
		# when we actually compile our source, we are compiling a combined file, which causes us to
		# lose filename and line number information when we have syntax errors.
		@renderContent input, options, (->) for input in inputs
		@renderContent inputs.join("\n\n"), options, callback
	
	# TODO
	# renderIndexContent: (input, options, callback) ->
