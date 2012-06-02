##
## squire.coffee
## 
## The entry point into our library when including via require. It's mostly useful for the base
## plugin class to be extended by any actual plugins.
##

lib =
	fs:     require "fs"
	path:   require "path"
	colors: require "colors"


# This class is a simple collection of utility functions. It is extended by SquirePlugin, and an
# instance of it is also exported via exports.util to provide direct access to the utility
# functions.
class Squire
	# Prints a nicely-formatted error message.
	logError: (explanation, message) ->
		explanation = lib.colors.red "\u2718 #{explanation}"
		
		if message?
			message = message.replace /\n/g, "\n    "
			console.log "\n#{explanation}\n\n    #{message}\n"
		else
			console.log "\n#{explanation}\n"
	
	# A little helper function to gather up a bunch of useful information about a url.
	getUrlInfo: (url) ->
		path      = lib.path.dirname url
		fileName  = lib.path.basename url
		extension = lib.path.extname(fileName)[1..]
		baseName  = fileName[0...fileName.length - extension.length - 1]
		
		url:                url
		fileName:           fileName
		baseName:           fileName[0...fileName.length - extension.length - 1]
		path:               path
		extension:          extension
		fileNameComponents: fileName.split "."
		pathComponents:     path.split("/")[1..]
	
	# Takes a list of paths and combines their contents into a single destination file, separated
	# by two newlines.
	combineFiles: (urls, destination) ->
		lib.fs.unlinkSync destination if lib.path.existsSync destination
		combinedContent = []
		combinedContent.push lib.fs.readFileSync(url) for url in urls
		lib.fs.writeFileSync destination, combinedContent.join("\n\n") + "\n"


# The base plugin class, to be extended by actual plugins.
class exports.SquirePlugin extends Squire
	configDefaults: {}
	
	renderContent: (input, options, callback) ->
		@logError "A plugin's renderContent function must be implemented."
		callback null
	
	renderContentList: (inputs, options, callback) ->
		result = ""
		
		recursiveRender = (index) =>
			input = inputs[index]
			
			@renderContent input, options, (content) ->
				result += "#{content}\n\n"
				if ++index < inputs.length then recursiveRender index else callback result
		
		if inputs.length > 0 then recursiveRender 0 else callback null
	
	renderIndexContent: (input, options, callback) ->
		# By default, index files will be treated just like normal files.
		# TODO: This is probably not good, because the output URL will have an HTML extension.
		@renderContent input, options, callback


# The app content tree that gets passed in to plugins is comprised of instances of this class.
# TODO: Implement this.
class exports.ContentFile
	constructor: (@fileName) ->


# We expose an instance of Squire to provide access to utility functions.
exports.util = new Squire
