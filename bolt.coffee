##
## bolt.coffee
## 
## The entry point into our library when including via require. It's mostly useful for the base
## plugin class to be extended by any actual plugins.
##

lib =
	fs:     require "fs"
	path:   require "path"
	colors: require "colors"


# A small collection of helper utility functions.
exports.util =
	# Prints a nicely-formatted error message.
	logError: (explanation, message) ->
		explanation = lib.colors.red "\u2718 #{explanation}"
		
		if message?
			message = message.replace /\n/g, "\n    "
			console.log "\n#{explanation}\n\n    #{message}\n"
		else
			console.log "\n#{explanation}\n"
	
	# A little helper function to gather up a bunch of useful information about a url.
	getUrlInfo: (url, basePath = @inputPath) ->
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
class exports.BasePlugin
	logError: (explanation, message) -> exports.util.logError explanation, message
	getUrlInfo:                (url) -> exports.util.getUrlInfo url
	
	buildFile: (inputUrl, outputUrl, callback) ->
		@logError "A plugin's buildFile function must be implemented."
	
	buildFiles: (inputUrls, outputUrl, callback) ->
		tempUrls       = []
		builtFileCount = 0
		
		for inputUrl, index in inputUrls
			tempUrl = "#{outputUrl}_#{index}"
			tempUrls.push tempUrl
			
			@buildFile inputUrl, tempUrl, ->
				if ++builtFileCount is inputUrls.length
					exports.util.combineFiles tempUrls, outputUrl
					lib.fs.unlinkSync tempUrl for tempUrl in tempUrls when lib.path.existsSync tempUrl
					callback()
	
	buildIndexFile: (inputUrl, outputUrl, callback) ->
		# By default, index files will be treated just like normal files.
		# TODO: This is probably not good, because the output URL will have an HTML extension.
		@buildFile inputUrl, outputUrl, callback
