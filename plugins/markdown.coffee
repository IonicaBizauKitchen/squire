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
			templatePlugin:        "jade"
			localsProperty:        "locals"
			headerSeparatorString: "~"
			sectionString:         "::"
	
	renderContent: (input, options, callback) ->
		[markdown, data] = @parseInput input
		
		if data.constructor is Error
			error = @createError "There was an error while parsing your Markdown file's CSON header data.", data.toString(), options.url
			callback null, null, error
		else
			callback lib.markdown(markdown), data
	
	renderIndexContent: (input, options, callback) ->
		templatePlugin = @loadPlugin @config.templatePlugin
		
		if templatePlugin?
			@renderContent input, options, (html, data, error) =>
				# TODO: Much of this is duplicated in the CoffeeScript module. Should share the code.
				if error?
					callback null, null, error
				else if data?.template?
					localsProperty = @config.localsProperty
					templateUrl    = "#{@appPath}/#{data.template}"
					template       = @loadTextFile templateUrl
					
					if template?
						templateOptions                 = { url: templateUrl }
						templateOptions[localsProperty] = { data: data, html: html }
						templatePlugin.renderIndexContent template, templateOptions, callback
					else
						error = @createError "Template file does not exist at #{templateUrl}."
						callback null, null, error
				else
					callback html, data
		else
			super
	
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
		sectionsByName   = {}
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
