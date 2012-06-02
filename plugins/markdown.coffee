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
		global:
			templatePlugin:  "jade"
			localsProperty:  "locals"
			separatorString: "~"
	
	renderContent: (input, options, callback) ->
		[markdown, data] = @parseInput input
		
		if data.constructor is Error
			message = data.toString()
			message = "In #{options.url}:\n\n#{message}" if options.url?
			@logError "There was an error while parsing your Markdown file's CSON header data.", message
			callback null
		else
			callback lib.markdown(markdown), data
	
	renderIndexContent: (input, options, callback) ->
		templatePlugin = @loadPlugin @config.templatePlugin
		
		if templatePlugin?
			@renderContent input, options, (html, data) =>
				if data?.template?
					localsProperty                  = @config.localsProperty
					template                        = @loadFile data.template
					templateOptions                 = { url: data.template }
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
			if line.trim().indexOf(@config.separatorString) is 0
				data     = lib.cson.parseSync lines[0..index - 1].join("\n")
				markdown = lines[index + 1..].join "\n"
				break
		
		[markdown, data]
