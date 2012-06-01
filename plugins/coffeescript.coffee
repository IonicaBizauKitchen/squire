##
## plugins/coffeescript.coffee
## 
## A plugin to handle CoffeeScript files.
##

lib =
	fs:     require "fs"
	squire: require "../squire"
	exec:   require("child_process").exec

class exports.Plugin extends lib.squire.BasePlugin
	inputExtensions: ["coffee"]
	outputExtension: "js"
	
	buildFile: (inputUrl, outputUrl, callback) ->
		lib.exec "coffee -p #{inputUrl} > #{outputUrl}", (error, stdout, stderr) =>
			@logCoffeeScriptError error if error?
			callback()
	
	buildFiles: (inputUrls, outputUrl, callback) ->
		fileArguments = inputUrls.join " "
		
		# We first need to check for syntax errors. We have to do this as a separate step because
		# when we actually compile our source, we are compiling a combined file, which causes us to
		# lose filename and line number information when we have syntax errors.
		lib.exec "coffee -p #{fileArguments}", (error, stdout, stderr) =>
			if error?
				@logCoffeeScriptError error
				return
			
			lib.exec "coffee -pjb #{fileArguments} > #{outputUrl}", (error, stdout, stderr) =>
				@logCoffeeScriptError error if error?
				callback()
	
	# TODO
	# buildIndexFile: (inputUrl, outputUrl, callback) ->
	
	logCoffeeScriptError: (error) ->
		# Remove extra cruft from the error message.
		message = error.toString().split("\n")[0]
		prefix  = "Error: Command failed: "
		message = message.slice prefix.length if message.indexOf(prefix) >= 0
		@logError "There was an error while compiling your CoffeeScript:", message
