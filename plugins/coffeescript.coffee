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

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["coffee"]
	outputExtension: "js"
	
	configDefaults:
		global:
			templatePlugin: "jade"
			localsProperty: "locals"
	
	renderContent: (input, options, callback) ->
		js = null
		
		try
			js = lib.coffee.compile input, options.compilerOptions or {}
			callback js
		catch error
			message = error.toString().split("\n")[0]
			message = "In #{options.url}:\n\n#{message}" if options.url?
			@logError "There was an error while compiling your CoffeeScript:", message
			callback null
	
	renderContentList: (inputs, options, callback) ->
		# We first need to check for syntax errors. We have to do this as a separate step because
		# when we actually compile our source, we are compiling a combined file, which causes us to
		# lose filename and line number information when we have syntax errors.
		validInputCount   = 0
		invalidInputCount = 0
		
		for input, index in inputs
			url = options.urls?[index]
			
			@renderContent input, (if url? then { url: url } else {}), (output) =>
				if output?
					@renderContent inputs.join("\n\n"), options, callback if ++validInputCount is inputs.length
				else
					invalidInputCount++
				
				callback null if invalidInputCount > 0 and invalidInputCount + validInputCount is inputs.length
	
	renderIndexContent: (input, options, callback) ->
		templatePlugin = @loadPlugin @config.templatePlugin
		
		if templatePlugin?
			options.compilerOptions = lib.merge (options.compilerOptions or {}), { bare: true }
			
			@renderContent input, options, (js) =>
				if js?
					# TODO: We should send a copy of @content.
					data = @evaluateIndexContent.call null, js, @content
					
					if data?.template?
						localsProperty                  = @config.localsProperty
						template                        = @loadFile data.template
						templateOptions                 = { url: data.template }
						templateOptions[localsProperty] = { data: data }
						
						templatePlugin.renderIndexContent template, templateOptions, callback
					else
						callback js
				else
					callback null
		else
			super
	
	# This is a pretty hacky way to provide some data to the user's code. We eval the compiled
	# JavaScript so that any local variables are accessible to it. This has potential to cause some
	# issues if the script starts modifying global data, but it doesn't have access to very much so
	# the risk is pretty small.
	evaluateIndexContent: (_js, content) ->
		eval _js
