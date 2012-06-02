##
## plugins/markdown.coffee
## 
## A plugin to handle Markdown files.
##

lib =
	markdown: require("markdown-js").markdown
	squire:   require "../squire"
	fs:       require "fs"

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["md", "markdown"]
	outputExtension: "html"
	
	configDefaults:
		templatePlugin: "jade"
		localsProperty: "locals"
	
	renderContent: (input, options, callback) ->
		callback lib.markdown(input)
	
	renderIndexContent: (input, options, callback) ->
		# TEMP: Disabling this until we implement @loadPlugin, @loadFile, etc.
		callback null
		return
		
		templatePlugin = @loadPlugin @config.templatePlugin
		
		if templatePlugin? and options.template?
			data     = {}                # TODO: Grab this from the top of the file, parsed through CSON.
			markdown = "*test content!*" # TODO: This is the rest of the file that isn't part of the data.
			
			@buildFile markdown, options, (html) =>
				localsProperty                  = @config.localsProperty
				template                        = @loadFile options.template
				templateOptions                 = {}
				templateOptions[localsProperty] = { data: data, html: html }
				templatePlugin.buildIndexFile template, templateOptions, callback
		else
			super
