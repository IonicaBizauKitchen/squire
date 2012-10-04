##
## plugins/markdown.coffee
## 
## A plugin to handle Markdown files.
##

lib =
	squire:   require "../main"
	markdown: require("markdown-js").markdown
	cson:     require "cson"

class MarkdownPlugin extends lib.squire.Plugin
	inputExtensions: ["md", "markdown"]
	outputExtension: "html"
	
	configDefaults:
		global:
			templatePlugin:        "jade"
			localsProperty:        "locals"
			headerSeparatorString: "~"
			sectionString:         "::"
	
	renderContent: (input, options, callback) ->
		[markdown, data] = @parseInput input
		
		if data.constructor is Error
			callback null, null, [@createError message: "There was an error while parsing your Markdown file's CSON header data.", details: data.toString(), path: options.path]
		else
			html = lib.markdown markdown
			
			if data.template?
				templatePlugin = @loadPlugin @config.templatePlugin
				
				if templatePlugin?
					localsProperty = @config.localsProperty
					templatePath   = "#{@appPath}/#{data.template}"
					template       = @loadTextFile templatePath
					
					if template?
						templateOptions                 = { path: templatePath }
						templateOptions[localsProperty] = { data: data, html: html }
						templatePlugin.renderIndexContent template, templateOptions, callback
					else
						callback null, null, [@createError message: "Template file does not exist at #{templatePath}."]
				else
					callback null, null, [@createError message: "Unable to load plugin #{@config.templatePlugin}.", path: options.path]
			else
				callback html, data
	
	renderAppTreeContent: (input, options, callback) ->
		@renderContent input, options, callback
	
	# A helper function to parse the header data and sections from the file. It returns two values
	# -- the first is an object with the CSON and section data and the second is the remaining
	# markdown text.
	parseInput: (input) ->
		data     = {}
		markdown = input
		
		# Parse the header data if it exists.
		headerSeparator = "\n#{@config.headerSeparatorString}\n"
		separatorIndex  = input.indexOf headerSeparator
		
		if separatorIndex >= 0
			data     = lib.cson.parseSync input[0...separatorIndex]
			markdown = input[separatorIndex + headerSeparator.length...]
		
		# Parse out the sections.
		lines            = markdown.split "\n"
		currentSection   = ""
		currentName      = ""
		unparsedSections = []
		sections         = []
		sectionPattern   = new RegExp "^#{@config.sectionString}\\s*(.*)$"
		
		for line, index in lines
			match = sectionPattern.exec line.trim()
			
			if match? or index is lines.length - 1
				if currentSection.trim().length > 0
					parsedSection = lib.markdown currentSection
					unparsedSections.push currentSection
					sections.push parsedSection
					sections[currentName] = parsedSection if currentName.length > 0
				
				currentSection = ""
				currentName    = match?[1]?.trim() or ""
			else
				currentSection += "#{line}\n"
		
		# Save off the markdown and the sections.
		markdown      = unparsedSections.join("\n\n") if unparsedSections.length > 0
		data.sections = sections
		
		[markdown, data]

# Expose plugin.
exports.Plugin = MarkdownPlugin
