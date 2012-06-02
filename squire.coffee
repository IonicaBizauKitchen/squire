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
	
	constructor: (@mode = "build") ->
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
			plugin         = new pluginModule.Plugin pluginId, @mode
			plugin.content = @content
			plugin
		else
			null
	
	# A helper function that will load a file at the given URL and return the contents. It will
	# accept both absolute URLs and URLs relative to a particular base path.
	loadFile: (url, basePath = @appPath) ->
		url = lib.path.join basePath, url if url[0] isnt "/"
		lib.fs.readFileSync(url).toString()
	
	# Prints a nicely-formatted error message.
	logError: (explanation, message) ->
		explanation = lib.colors.red "\u2718 #{explanation}"
		
		if message?
			message = message.replace /\n/g, "\n    "
			console.log "\n#{explanation}\n\n    #{message}\n"
		else
			console.log "\n#{explanation}\n"
	
	# A little helper function to gather up a bunch of useful information about a url.
	getUrlInfo: (url, basePath = @appPath) ->
		path         = lib.path.dirname url
		fileName     = lib.path.basename url
		extension    = lib.path.extname(fileName)[1..]
		baseName     = fileName[0...fileName.length - extension.length - 1]
		relativePath = path[basePath.length + 1..]
		
		url:                    url
		fileName:               fileName
		baseName:               fileName[0...fileName.length - extension.length - 1]
		path:                   path
		extension:              extension
		fileNameComponents:     fileName.split "."
		pathComponents:         path.split("/")[1..]
		relativePath:           relativePath
		relativeUrl:            if relativePath then "#{relativePath}/#{fileName}" else fileName
		relativePathComponents: relativePath.split "/"


# The base plugin class, to be extended by actual plugins.
class exports.SquirePlugin extends exports.Squire
	configDefaults: {}
	
	constructor: (@id, @mode = "build") ->
		super @mode
		
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
		result = ""
		
		recursiveRender = (index) =>
			input = inputs[index]
			url   = options.urls?[index]
			
			@renderContent input, (if url? then { url: url } else {}), (content) ->
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
