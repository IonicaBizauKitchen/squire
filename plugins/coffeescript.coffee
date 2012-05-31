##
## plugins/coffeescript.coffee
## 
## A plugin to handle coffeescript files.
##

lib =
	bolt: require "../bolt"
	exec: require("child_process").exec

class exports.Plugin extends lib.bolt.BasePlugin
	inputExtensions: ["coffee"]
	outputExtension: "js"
	
	buildFile: (inputUrl, outputUrl, callback) ->
		lib.exec "coffee -p #{inputUrl} > #{outputUrl}", (error, stdout, stderr) =>
			@logCoffeeScriptError error if error?
			callback()
	
	# TODO
	# buildFiles: (inputUrls, outputUrl, callback) ->	
	# 	callback()
	
	# TODO
	# buildIndexFile: (inputUrl, outputUrl, callback) ->
	
	logCoffeeScriptError: (error) ->
		# Remove extra cruft from the error message.
		message = error.toString().split("\n")[0]
		prefix  = "Error: Command failed: "
		message = message.slice prefix.length if message.indexOf(prefix) >= 0
		@logError "There was an error while compiling your CoffeeScript:", message
