##
## classes/url_info.coffee
## 
## A helper utility class for parsing a URL and providing access to various information about it.
##

lib =
	fs:     require "fs"
	path:   require "path"
	squire: require "../squire"

# We need a Squire instance to get things like the output path, plugins, etc.
squire = new lib.squire.Squire

exports.UrlInfo = class
	constructor: (url, @basePath = squire.appPath) -> @url = url
	
	Object.defineProperty @prototype, "url",
		get:       -> @_url
		set: (url) ->
			url   = "#{@basePath}/#{url}"   if @basePath and url[0] isnt "/"
			url   = url[0...url.length - 1] if url[url.length - 1] is "/"
			@_url = url
	
	Object.defineProperty @prototype, "exists",                 get: -> lib.fs.existsSync @url
	Object.defineProperty @prototype, "isDirectory",            get: -> @exists and lib.fs.lstatSync(@url).isDirectory()
	Object.defineProperty @prototype, "path",                   get: -> if @isDirectory then @url else lib.path.dirname @url
	Object.defineProperty @prototype, "relativePath",           get: -> @path[@basePath.length + 1...]
	Object.defineProperty @prototype, "fileName",               get: -> if @isDirectory then null else lib.path.basename @url
	Object.defineProperty @prototype, "extension",              get: -> if @isDirectory then null else lib.path.extname(@fileName)[1..]
	Object.defineProperty @prototype, "relativeUrl",            get: -> if @isDirectory then null else "#{@relativePath}/#{@fileName}"
	Object.defineProperty @prototype, "components",             get: -> @url.split("/")[1...]
	Object.defineProperty @prototype, "pathComponents",         get: -> @path.split("/")[1...]
	Object.defineProperty @prototype, "relativePathComponents", get: -> @relativePath.split "/"
	Object.defineProperty @prototype, "fileNameComponents",     get: -> @fileName?.split "."
	
	Object.defineProperty @prototype, "baseName", get: ->
		if @isDirectory
			lib.path.basename @url
		else
			{fileName} = this
			fileName[0...fileName.length - @extension.length - 1]
	
	Object.defineProperty @prototype, "isConcatFile", get: -> @fileNameComponents[1] is "concat"
	Object.defineProperty @prototype, "isIndexFile",  get: -> @baseName is "index"
	Object.defineProperty @prototype, "isEcoFile",    get: -> @extension is "eco"
	Object.defineProperty @prototype, "plugin",       get: -> squire.plugins[@extension] or squire.defaultPlugin
	
	Object.defineProperty @prototype, "outputUrlInfo", get: ->
		outputPath      = lib.path.join squire.outputPath, @relativePath
		outputBaseName  = @baseName.replace(".concat", "").replace ".eco", ""
		outputExtension = if @isIndexFile then "html" else @plugin.outputExtension or @extension
		outputUrl       = "#{outputPath}/#{outputBaseName}"
		outputUrl      += ".#{outputExtension}" if outputExtension
		new exports.UrlInfo outputUrl, squire.outputPath
