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
	cson:   require "cson"
	merge:  require "deepmerge"


# This class provides some base functionality that's used throughout the project. It is extended by
# SquirePlugin as well as each command in our command-line utility.
class exports.Squire
	baseConfigDefaults:
		global:
			appDirectory:      "app"
			inputDirectory:    "content"
			outputDirectory:   "build"
			ignoreHiddenFiles: true
		preview:
			minify: false
		build:
			minify: true
	
	constructor: (options = {}) ->
		@mode = options.mode or "build"
		
		# Gather up config values.
		@projectPath   = process.env.PWD
		userConfigPath = "#{@projectPath}/config/squire.cson"
		userConfig     = if lib.path.existsSync userConfigPath then lib.cson.parseFileSync(userConfigPath) or {} else {}
		@config        = lib.merge @baseConfigDefaults, userConfig
		@config        = lib.merge @config.global, @config[@mode]
		
		# Store some useful paths.
		@squirePath = __dirname
		@appPath    = "#{@projectPath}/#{@config.appDirectory.trim()}"
		@inputPath  = "#{@appPath}/#{@config.inputDirectory.trim()}"
		@outputPath = "#{@projectPath}/#{@config.outputDirectory.trim()}"
	
	# Takes in a plugin ID and returns a new instance of that plugin, or null if the plugin doesn't
	# exist or can't be loaded.
	loadPlugin: (pluginId) ->
		pluginModule = null
		
		paths = [
			"#{@projectPath}/plugins/#{pluginId}.coffee"
			"#{@squirePath}/plugins/#{pluginId}.coffee"
			"squire-#{pluginId}"
		]
		
		# Look for the module in several different places.
		for path in paths
			# Check if the plugin exists at this location.
			# TODO: This is really hacky. The try/catch will catch both module-not-found errors and
			# errors with the plugins themselves. Is there a better way to check if a module exists
			# at the given path?
			try
				pluginModule = require path
				break
			catch error
				throw error unless error.toString().indexOf("Error: Cannot find module") is 0
		
		if pluginModule?
			plugin     = new pluginModule.Plugin id: pluginId, mode: @mode
			plugin.app = @app
			plugin
		else
			null
	
	# A helper function that will load a file at the given URL and return the contents. It will
	# accept both absolute URLs and URLs relative to a particular base path.
	loadFile: (url, basePath = @appPath) ->
		url = lib.path.join basePath, url if url[0] isnt "/"
		lib.fs.readFileSync(url).toString()
	
	# Prints a nicely-formatted error message. Also returns the error for further use.
	logError: (message, details, url) ->
		fancyMessage = lib.colors.red "\u2718 #{message}"
		error        = "\n#{message}"
		fancyError   = "\n#{fancyMessage}"
		
		if details?
			details    = "\n#{details}\n"
			details    = "\nIn #{url}:\n#{details}" if url?
			details    = details.replace /\n/g, "\n    "
			error      += "\n#{details}"
			fancyError += "\n#{details}"
		else if url?
			error      += " in #{url}"
			fancyError += " in #{url}"
		
		console.log fancyError
		error
	
	# A little helper function to gather up a bunch of useful information about a url.
	getUrlInfo: (url, basePath = @appPath) ->
		url                    = "#{basePath}/#{url}" unless url[0] is "/"
		url                    = url[0..url.length - 2] if url[url.length - 1] is "/"
		exists                 = lib.path.existsSync url
		isDirectory            = if exists then lib.fs.lstatSync(url).isDirectory() else url.lastIndexOf("/") > url.lastIndexOf(".")
		path                   = if isDirectory then url else lib.path.dirname url
		pathComponents         = path.split("/")[1..]
		relativePath           = path[basePath.length + 1..]
		relativePathComponents = relativePath.split "/"
		
		if isDirectory
			url:                    url
			baseName:               lib.path.basename url
			components:             pathComponents
			relativePath:           relativePath
			relativePathComponents: relativePathComponents
			isDirectory:            true
		else
			fileName  = lib.path.basename url
			extension = lib.path.extname(fileName)[1..]
			
			url:                    url
			fileName:               fileName
			baseName:               fileName[0...fileName.length - extension.length - 1]
			path:                   path
			extension:              extension
			fileNameComponents:     fileName.split "."
			pathComponents:         pathComponents
			relativePath:           relativePath
			relativeUrl:            if relativePath then "#{relativePath}/#{fileName}" else fileName
			relativePathComponents: relativePathComponents
			isDirectory:            false


# The base plugin class, to be extended by actual plugins.
class exports.SquirePlugin extends exports.Squire
	configDefaults: {}
	fileType:       "text"
	
	constructor: (options = {}) ->
		super
		@id = options.id
		
		# We add to the base config with our plugin-specific config.
		userConfigPath = "#{@projectPath}/config/#{@id}.cson"
		userConfig     = if lib.path.existsSync userConfigPath then lib.cson.parseFileSync(userConfigPath) or {} else {}
		pluginConfig   = lib.merge { global: {}, preview: {}, build: {} }, @configDefaults
		pluginConfig   = lib.merge pluginConfig, userConfig
		pluginConfig   = lib.merge pluginConfig.global, pluginConfig[@mode]
		@config        = lib.merge @config, pluginConfig
	
	renderContent: (input, options, callback) ->
		callback input
	
	renderContentList: (inputs, options, callback) ->
		results = []
		errors  = []
		
		recursiveRender = (index) =>
			input = inputs[index].toString()
			url   = options.urls?[index]
			
			@renderContent input, (if url? then { url: url } else {}), (output, data, error) ->
				if error? then errors.push error else results.push output
				
				if ++index < inputs.length
					recursiveRender index
				else if errors.length > 0
					callback null, null, errors.join("\n\n")
				else
					callback results.join("\n\n")
		
		if inputs.length > 0 then recursiveRender 0 else callback ""
	
	renderIndexContent: (input, options, callback) ->
		# By default, index files will be treated just like normal files.
		@renderContent input, options, callback


# A class that represents a directory. The content tree is comprised of these and SquireFiles.
class exports.SquireDirectory extends exports.Squire
	constructor: (options = {}) ->
		super
		@path          = options.path
		pathComponents = @path.split "/"
		@name          = pathComponents[pathComponents.length - 1]
		@directories   = {}
		@files         = {}
	
	getPath: (path) ->
		path = path[1..] while path[0] is "/"
		
		if path.length is 0
			this
		else
			directory      = this
			pathComponents = path.split "/"
			
			for component in pathComponents
				directory = directory.directories[component]
				break unless directory?
			
			directory
	
	walk: (callback) ->
		callback this
		directory.walk callback for name, directory of @directories


# A class that represents a file. The content tree is comprised of these and SquireDirectories.
class exports.SquireFile extends exports.Squire
	constructor: (options = {}) ->
		super
		@url     = options.url
		urlInfo  = @getUrlInfo @url
		@name    = urlInfo.fileName
		@plugin  = options.plugin
		@content = options.content
	
	getRenderedContent: (callback) ->
		@plugin.renderContent @content, {}, (output) -> callback output
