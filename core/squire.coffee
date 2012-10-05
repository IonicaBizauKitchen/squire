##
## core/squire.coffee
## 
## Defines the base Squire class that is used throughout the package. It is extended by most other
## classes, including Plugin and each command class.
##

lib =
	cson:   require "cson"
	fs:     require "fs"
	merge:  require "deepmerge"
	path:   require "path"
	squire: require "../main"

staticData =
	# We maintain a single, persistent list of plugins here so that each instance of Squire doesn't
	# load up its own copies of the plugins.
	plugins: null
	
	# We also maintain a reference to the default plugin in the same way.
	defaultPlugin: null
	
	# Another reference to the app content tree. This gets populated by constructAppTree.
	app: null

class Squire
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
	Object.defineProperty @prototype, "plugins", get: -> (@loadPlugins() unless staticData.plugins?); staticData.plugins
	
	# Same as above but for the default plugin.
	Object.defineProperty @prototype, "defaultPlugin", get: -> (@loadPlugins() unless staticData.defaultPlugin?); staticData.defaultPlugin
	
	# Again, same as above but for the app tree, except it doesn't get loaded automatically.
	Object.defineProperty @prototype, "app",
		get:       -> staticData.app
		set: (app) -> staticData.app = app
	
	# Loads all of the plugins. Generally you won't need to call this manually -- it will be called
	# automatically as necessary when trying to access the plugins property. You can call it if you
	# need to reload the plugins, however.
	loadPlugins: ->
		staticData.defaultPlugin             = new lib.squire.Plugin id: "default"
		staticData.defaultPlugin.contentType = "binary"
		staticData.plugins                   = []
		
		return unless @config.plugins?
		
		for pluginId in @config.plugins
			plugin = @loadPlugin pluginId
			
			unless plugin?
				@logError "Plugin #{pluginId} could not be loaded."
				continue
			
			unless plugin.inputExtensions?.length > 0
				@logError "Plugin #{pluginId} does not define any associated input extensions."
				continue
			
			staticData.plugins.push plugin
			staticData.plugins[extension] = plugin for extension in plugin.inputExtensions
	
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
		for path in paths when lib.fs.existsSync path
			pluginModule = require path
			break
		
		if pluginModule?
			new pluginModule.Plugin id: pluginId, mode: @mode
		else
			null
	
	# A helper function that will load a file at the given URL and return the contents.
	loadFile: (path) ->
		if lib.fs.existsSync path
			lib.fs.readFileSync path
		else
			null
	
	# The same as above, but will automatically convert the loaded file buffer to a string.
	loadTextFile: (path) ->
		@loadFile(path)?.toString()

# Expose class.
exports.Squire = Squire
