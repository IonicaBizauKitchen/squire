##
## classes/squire_plugin.coffee
## 
## Define the base Squire plugin class that's used for all plugins.
##

lib =
	fs:     require "fs"
	cson:   require "cson"
	merge:  require "deepmerge"
	squire: require "../squire"

# The base plugin class, to be extended by actual plugins.
exports.SquirePlugin = class extends lib.squire.Squire
	configDefaults: {}
	fileType:       "text"
	
	constructor: (options = {}) ->
		super
		@id = options.id
		
		# We add to the base config with our plugin-specific config.
		userConfigPath = "#{@projectPath}/config/#{@id}.cson"
		userConfig     = if lib.fs.existsSync userConfigPath then lib.cson.parseFileSync(userConfigPath) or {} else {}
		pluginConfig   = lib.merge { global: {}, preview: {}, build: {} }, @configDefaults
		pluginConfig   = lib.merge pluginConfig, userConfig
		pluginConfig   = lib.merge pluginConfig.global, pluginConfig[@mode] or {}
		@config        = lib.merge @config, pluginConfig
	
	renderContent: (input, options, callback) ->
		callback input
	
	renderContentList: (inputs, options, callback) ->
		results   = []
		allErrors = []
		
		recursiveRender = (index) =>
			input = inputs[index].toString()
			url   = options.urls?[index]
			
			@renderContent input, (if url? then { url: url } else {}), (output, data, errors) ->
				if errors?
					allErrors = allErrors.concat errors
				else
					results.push output
				
				if ++index < inputs.length
					recursiveRender index
				else if allErrors.length > 0
					callback null, null, allErrors
				else
					callback results.join("\n\n")
		
		if inputs.length > 0 then recursiveRender 0 else callback ""
	
	renderIndexContent: (input, options, callback) ->
		# By default, index content will be treated just like normal content.
		@renderContent input, options, callback
	
	renderAppTreeContent: (input, options, callback) ->
		# By default, the raw input of each file goes into the app tree.
		callback input
	
	postProcessContent: (input, options, callback) ->
		# By default, post processing does nothing.
		callback input
