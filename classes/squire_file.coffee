##
## classes/squire_file.coffee
## 
## A class that represents a file. The app tree is comprised of these and SquireDirectories.
##

lib =
	squire: require "../squire"

exports.SquireFile = class extends lib.squire.Squire
	constructor: (options = {}) ->
		super
		@path       = options.path
		@publicPath = options.publicPath
		urlInfo     = new lib.squire.UrlInfo @path
		@name       = urlInfo.fileName
		@plugin     = options.plugin
		@content    = options.content
	
	# A getter for the content. It will load and process the content on demand.
	# Object.defineProperty @prototype, "content", get: ->
