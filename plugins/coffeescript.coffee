##
## plugins/coffeescript.coffee
## 
## A plugin to handle CoffeeScript files.
##

lib =
	squire: require "../main"
	fs:     require "fs"
	coffee: require "coffee-script"
	merge:  require "deepmerge"
	_:      require "underscore"

class CoffeeScriptPlugin extends lib.squire.Plugin
	inputExtensions: ["coffee"]
	outputExtension: "js"
	
	configDefaults:
		global:
			templatePlugin: "jade"
			localsProperty: "locals"
			wrapFiles:      true
	
	renderContent: (input, options, callback) ->
		js              = null
		errors          = null
		compilerOptions = lib.merge options.compilerOptions or {}, { bare: !@config.wrapFiles }
		
		try
			js = lib.coffee.compile input, compilerOptions
		catch compileError
			errors = [@createCoffeeScriptError error: compileError, path: options.path]
		
		callback js, null, errors
	
	renderContentList: (inputs, options, callback) ->
		# We first need to check for syntax errors. We have to do this as a separate step because
		# when we actually compile our source, we are compiling a combined file, which causes us to
		# lose filename and line number information when we have syntax errors.
		allErrors      = []
		outputs        = []
		builtFileCount = 0
		
		for input, index in inputs
			path = options.paths?[index]
			
			@renderContent input, (if url? then {path} else {}), (output, data, errors = []) =>
				allErrors = allErrors.concat errors
				outputs.push output
				
				if ++builtFileCount is inputs.length
					if allErrors.length > 0
						callback null, null, allErrors
					else if @config.wrapFiles
						callback outputs.join("\n\n")
					else
						@renderContent inputs.join("\n\n"), options, callback
	
	renderIndexContent: (input, options, callback) ->
		templatePlugin = @loadPlugin @config.templatePlugin
		
		if templatePlugin?
			try
				input = lib.coffee.eval input
			catch error
				callback null, null, [@createCoffeeScriptError error: error, path: options.path]
				return
			
			dataFunction = input.pageData or input.pageDataAsync
			
			if typeof(dataFunction) is "function"
				functionType = if input.pageData? then "sync" else "async"
				
				done = (data) =>
					if data?.template?
						localsProperty = @config.localsProperty
						templatePath   = "#{@appPath}/#{data.template}"
						template       = @loadTextFile templatePath
						
						if template?
							templateOptions                 = path: templatePath
							templateOptions[localsProperty] = data: data
							templatePlugin.renderIndexContent template, templateOptions, callback
						else
							callback null, null, [@createError message: "Template file does not exist at #{templatePath}."]
					else
						super
				
				if functionType is "sync"
					done dataFunction(@app, lib._)
				else
					dataFunction @app, lib._, (data) => done data
			else
				super
		else
			super
	
	createCoffeeScriptError: (options) ->
		options.message     = "There was an error while compiling your CoffeeScript:"
		options.description = options.error.toString().split("\n")[0]
		@createError options

# Expose plugin.
exports.Plugin = CoffeeScriptPlugin
