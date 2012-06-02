##
## plugins/markdown.coffee
## 
## A plugin to handle Markdown files.
##

lib =
	markdown: require("markdown-js").markdown
	squire:   require "../squire"

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["md", "markdown"]
	outputExtension: "html"
	
	configDefaults:
		templatePlugin: "jade"
		localsProperty: "locals"
	
	renderContent: (input, options, callback) ->
		callback lib.markdown(input)
	
	renderIndexContent: (input, options, callback) ->
		templatePlugin = @loadPlugin @config.templatePlugin
		
		if templatePlugin?
			data     = { template: "templates/my_template.jade", yo: "dogg" } # TODO: Grab this from the top of the file, parsed through CSON.
			markdown = "*test content!*"                                      # TODO: This is the rest of the file that isn't part of the data.
			
			if data.template?
				@renderContent markdown, options, (html) =>
					localsProperty                  = @config.localsProperty
					template                        = @loadFile data.template
					templateOptions                 = {}
					templateOptions[localsProperty] = { data: data, html: html }
					
					templatePlugin.renderIndexContent template, templateOptions, callback
			else
				super
		else
			super
