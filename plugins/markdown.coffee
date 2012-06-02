##
## plugins/markdown.coffee
## 
## A plugin to handle Markdown files.
##

lib =
	markdown: require("markdown-js").markdown
	squire:   require "../squire"
	cson:     require "cson"

class exports.Plugin extends lib.squire.SquirePlugin
	inputExtensions: ["md", "markdown"]
	outputExtension: "html"
	
	configDefaults:
		templatePlugin: "jade"
		localsProperty: "locals"
	
	renderContent: (input, options, callback) ->
		[data, markdown] = @parseInput input
		callback lib.markdown(markdown), data
	
	renderIndexContent: (input, options, callback) ->
		templatePlugin = @loadPlugin @config.templatePlugin
		
		if templatePlugin?
			@renderContent input, options, (html, data) =>
				if data.template?
					localsProperty                  = @config.localsProperty
					template                        = @loadFile data.template
					templateOptions                 = {}
					templateOptions[localsProperty] = { data: data, html: html }
					
					templatePlugin.renderIndexContent template, templateOptions, callback
				else
					callback html, data
		else
			super
	
	# A helper function to parse the header data from the file. It returns two values -- the first
	# is an object with the CSON data and the second is the remaining markdown text.
	parseInput: (input) ->
		lines    = input.split "\n"
		data     = {}
		markdown = input
		
		for line, index in lines
			if line.trim()[0] is "~"
				data     = lib.cson.parseSync lines[0..index - 1].join("\n")
				markdown = lines[index + 1..].join "\n"
				break
		
		[data, markdown]
