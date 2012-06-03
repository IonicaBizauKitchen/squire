##
## plugins/coffeescript.coffee
## 
## A plugin to handle CoffeeScript files.
##

lib =
	fs:     require "fs"
	squire: require "../squire"
	coffee: require "coffee-script"
	merge:  require "deepmerge"
	_:      require "underscore"

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["coffee"]
	outputExtension: "js"
	
	configDefaults:
		global:
			templatePlugin: "jade"
			localsProperty: "locals"
	
	renderContent: (input, options, callback) ->
		js    = null
		error = null
		
		try
			js = lib.coffee.compile input, options.compilerOptions or {}
		catch compileError
			error = @logCoffeeScriptError compileError, options.url
		
		callback js, null, error
	
	renderContentList: (inputs, options, callback) ->
		# We first need to check for syntax errors. We have to do this as a separate step because
		# when we actually compile our source, we are compiling a combined file, which causes us to
		# lose filename and line number information when we have syntax errors.
		errors         = []
		builtFileCount = 0
		
		for input, index in inputs
			url = options.urls?[index]
			
			@renderContent input, (if url? then { url: url } else {}), (output, data, error) =>
				errors.push error if error?
				
				if ++builtFileCount is inputs.length
					if errors.length > 0
						callback null, null, errors.join("\n\n")
					else
						@renderContent inputs.join("\n\n"), options, callback
	
	renderIndexContent: (input, options, callback) ->
		templatePlugin = @loadPlugin @config.templatePlugin
		
		if templatePlugin?
			try
				input = lib.coffee.eval input
			catch error
				error = @logCoffeeScriptError error, options.url
				callback null, null, error
				return
			
			dataFunction = input.pageData or input.pageDataAsync
			
			if typeof(dataFunction) is "function"
				functionType = if input.pageData? then "sync" else "async"
				
				done = (data) =>
					if data?.template?
						localsProperty                  = @config.localsProperty
						template                        = @loadFile data.template
						templateOptions                 = { url: data.template }
						templateOptions[localsProperty] = { data: data }
						
						templatePlugin.renderIndexContent template, templateOptions, callback
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
	
	logCoffeeScriptError: (error, url) ->
		message = error.toString().split("\n")[0]
		@logError "There was an error while compiling your CoffeeScript:", message, url
