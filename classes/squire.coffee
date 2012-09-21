##
## classes/squire.coffee
## 
## Define the base Squire class that is used throughout the package. It is extended by most other
## classes, including SquirePlugin and each command class.
##

lib =
	fs:     require "fs"
	path:   require "path"
	file:   require "file"
	colors: require "colors"
	cson:   require "cson"
	merge:  require "deepmerge"
	squire: require "../squire"

# We maintain a single, persistent list of plugins here so that each instance of Squire doesn't
# load up its own copies of the plugins.
plugins = null

# We also maintain a reference to the default plugin in the same way.
defaultPlugin = null

# Another reference to the app content tree. This gets populated by constructAppTree.
app = null

exports.Squire = class
	baseConfigDefaults:
		global:
			appDirectory:      "app"
			inputDirectory:    "content"
			outputDirectory:   "build"
			ignoreHiddenFiles: true
			plugins:           []
			minify:            false
		preview:
			enableProxy: false
			proxyHost:   "localhost"
			proxyPort:   80
		build:
			minify: true
	
	constructor: (options = {}) ->
		@mode = options.mode or "build"
		
		# Gather up config values.
		@projectPath   = process.env.PWD
		userConfigPath = "#{@projectPath}/config/squire.cson"
		userConfig     = if lib.fs.existsSync userConfigPath then lib.cson.parseFileSync(userConfigPath) or {} else {}
		userConfig     = lib.merge userConfig.global or {}, userConfig[@mode] or {}
		@config        = lib.merge @baseConfigDefaults.global, @baseConfigDefaults[@mode] or {}
		@config        = lib.merge @config, userConfig
		
		# Store some useful paths.
		@squirePath = lib.path.join __dirname, ".."
		@appPath    = "#{@projectPath}/#{@config.appDirectory.trim()}"
		@inputPath  = "#{@appPath}/#{@config.inputDirectory.trim()}"
		@outputPath = "#{@projectPath}/#{@config.outputDirectory.trim()}"
	
	# A getter for the list of plugins. They will automatically be loaded if they haven't been yet.
	Object.defineProperty @prototype, "plugins", get: ->
		@loadPlugins() unless plugins?
		plugins
	
	# Same as above but for the default plugin.
	Object.defineProperty @prototype, "defaultPlugin", get: ->
		@loadPlugins() unless defaultPlugin?
		defaultPlugin
	
	# Again, same as above but for the app tree.
	Object.defineProperty @prototype, "app", get: ->
		app = new lib.squire.SquireDirectory path: "/", publicPath: null unless app?
		app
	
	# Constructs the app tree from all the files in the app directory.
	constructAppTree: (callback) ->
		builtFileCount = 0
		
		lib.file.walkSync @appPath, (path, directories, files) =>
			relativePath   = path[@appPath.length + 1..]
			currentContent = @app.getPath relativePath
			isInputPath    = path.indexOf(@inputPath) is 0
			
			for directoryName in directories
				continue if @config.ignoreHiddenFiles and directoryName[0] is "."
				
				urlInfo = new lib.squire.UrlInfo "#{path}/#{directoryName}"
				
				currentContent.directories[directoryName] = new lib.squire.SquireDirectory
					path:       "/#{urlInfo.relativePath}"
					publicPath: if isInputPath then urlInfo.url[@inputPath.length..] else null
			
			for fileName in files
				continue if @config.ignoreHiddenFiles and fileName[0] is "."
				
				url     = "#{path}/#{fileName}"
				urlInfo = new lib.squire.UrlInfo url
				input   = if urlInfo.plugin.fileType is "text" then @loadTextFile url else @loadFile url
				
				file = currentContent.files[fileName] = new lib.squire.SquireFile
					path:       "/#{urlInfo.relativeUrl}"
					publicPath: if isInputPath then urlInfo.url[@inputPath.length..] else null
					plugin:     urlInfo.plugin
				
				file.plugin.renderAppTreeContent input, { url: urlInfo.url }, (output = "", data = {}, errors) =>
					file.content = if errors? then @consolidateErrors(errors, "plain") else output
					file.data    = data
					callback?() if ++builtFileCount is @totalFileCount
	
	# Loads all of the plugins. Generally you won't need to call this manually -- it will be called
	# automatically as necessary when trying to access the plugins property.
	loadPlugins: ->
		defaultPlugin          = new lib.squire.SquirePlugin id: "default"
		defaultPlugin.fileType = "binary"
		plugins                = []
		
		return unless @config.plugins?
		
		for pluginId in @config.plugins
			plugin = @loadPlugin pluginId
			
			unless plugin?
				@logError "Plugin #{pluginId} could not be loaded."
				continue
			
			unless plugin.inputExtensions?.length > 0
				@logError "Plugin #{pluginId} does not define any associated input extensions."
				continue
			
			plugins.push plugin
			plugins[extension] = plugin for extension in plugin.inputExtensions
	
	# Takes in a plugin ID and returns a new instance of that plugin, or null if the plugin doesn't
	# exist or can't be loaded.
	loadPlugin: (pluginId) ->
		pluginModule = null
		
		paths = [
			"#{@projectPath}/plugins/#{pluginId}.coffee"
			"#{@squirePath}/plugins/#{pluginId}.coffee"
			"#{@projectPath}/node_modules/squire-#{pluginId}"
		]
		
		# Look for the module in several different places.
		for path in paths
			# If there's something at this path let's try to load it. Hopefully it's a plugin.
			if lib.fs.existsSync path
				pluginModule = require path
				break
		
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
		
		if lib.fs.existsSync url
			lib.fs.readFileSync url
		else
			null
	
	# The same as above, but will automatically convert the loaded file to a string. This is useful
	# if you know that the file you're loading is a text file and not binary like an image.
	loadTextFile: (url, basePath = @appPath) ->
		@loadFile(url, basePath).toString()
	
	# Creates a nicely formatted error message and returns it. Plugins use this to create an error
	# that they bubble up to the build process.
	createError: (message, details, url) ->
		fancyMessage = lib.colors.red "\u2718 #{message}"
		error        = "\n#{message}"
		fancyError   = "\n#{fancyMessage}"
		
		if details?
			details     = "\n#{details}"
			details     = "\nIn #{url}:\n#{details}" if url?
			details     = details.replace /\n/g, "\n    "
			error      += "\n#{details}"
			fancyError += "\n#{details}"
		else if url?
			error      += " in #{url}"
			fancyError += " in #{url}"
		
		error      += "\n"
		fancyError += "\n"
		
		{ plainMessage: error, fancyMessage: fancyError }
	
	# A convenience function for logging an error created by the above function.
	logError: (message, details, url) ->
		console.log @createError(message, details, url).fancyMessage
	
	# Takes in a list of error objects (generated by createError) and joins them into a single
	# string based on the error type you're interested ("fancy" or "plain").
	consolidateErrors: (errors, type = "fancy") ->
		(error["#{type}Message"] for error in errors).join "\n\n"
