##
## core/plugin.coffee
## 
## Define the base Squire plugin class that's used for all plugins.
##

lib =
	cson:   require "cson"
	fs:     require "fs"
	merge:  require "deepmerge"
	squire: require "../main"

class Plugin extends lib.squire.Squire
	configDefaults: {}
	contentType:    "text"
	
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
			path   = options.paths?[index]
			
			@renderContent input, (if path? then {path} else {}), (output, data, errors) ->
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
	
	# A convenience function for plugins to allow them to create errors without knowing about the
	# Error class.
	createError: (options) -> new lib.squire.Error options

# Expose class.
exports.Plugin = Plugin
