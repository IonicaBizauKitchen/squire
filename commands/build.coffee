##
## commands/build.coffee
## 
## This contains the implementation of the build command.
##

lib =
	_:      require "underscore"
	fs:     require "fs"
	path:   require "path"
	exec:   require("child_process").exec
	file:   require "file"
	wrench: require "wrench"
	squire: require "../squire"


class BuildCommand extends lib.squire.Squire
	# The entry point to the command.
	run: (options) ->
		@callback       = options.callback
		@totalFileCount = 0
		
		# Make sure we've got our directories set up properly.
		unless lib.path.existsSync @appPath
			@logError "Configured application path #{@appPath} does not exist."
			return
		
		unless lib.path.existsSync @inputPath
			@logError "Configured input path #{@inputPath} does not exist."
			return
		
		# Initialize the app content tree.
		@app = new lib.squire.SquireDirectory path: @appPath
		
		# Do the stuff to make the thing.
		@loadPlugins()
		@gatherAppContent()
		@buildFiles()
	
	
	# Loads all of the plugins specified by the user.
	loadPlugins: ->
		@defaultPlugin          = new lib.squire.SquirePlugin id: "default"
		@defaultPlugin.fileType = "binary"
		@plugins                = {}
		
		return unless @config.plugins?
		
		for pluginId in @config.plugins
			plugin = @loadPlugin pluginId
			
			unless plugin?
				@logError "Plugin #{pluginId} could not be loaded."
				continue
			
			unless plugin.inputExtensions?.length > 0
				@logError "Plugin #{pluginId} does not define any associated input extensions."
				continue
			
			@plugins[extension] = plugin for extension in plugin.inputExtensions
	
	
	# Gathers up all of the contents of the app directory.
	gatherAppContent: ->
		lib.file.walkSync @appPath, (path, directories, files) =>
			relativePath   = path[@appPath.length + 1..]
			currentContent = @app.getPath relativePath
			
			for directoryName in directories
				currentContent.directories[directoryName] = new lib.squire.SquireDirectory path: "#{path}/#{directoryName}"
			
			for fileName in files
				urlInfo = @getUrlInfo "#{path}/#{fileName}"
				
				currentContent.files[fileName] = new lib.squire.SquireFile
					url:     urlInfo.url
					plugin:  urlInfo.plugin
					content: @loadFile urlInfo.url
	
	
	# Runs through the content tree, building each file.
	buildFiles: ->
		errors = []
		
		# Start by counting the total number of files.
		lib.file.walkSync @inputPath, (path, directories, files) =>
			for fileName in files
				@totalFileCount++ unless @config.ignoreHiddenFiles and fileName[0] is "."
		
		# Clean the build folder. Since we're going to be running rm -rf, we do a little bit of
		# sanity checking to help prevent catastrophic occurrences.
		if @outputPath.indexOf(@projectPath) is 0
			lib.exec "rm -rf #{@outputPath}", (error, stdout, stderr) =>
				throw error if error?
				lib.fs.mkdirSync @outputPath, 0o0755
				
				# Fill up the output paths with the directory structure of the input path.
				lib.file.walkSync @inputPath, (path, directories, files) =>
					relativePath = path[@inputPath.length + 1..]
					outputPath   = "#{@outputPath}/#{relativePath}"
					lib.fs.mkdirSync "#{outputPath}/#{directoryName}" for directoryName in directories
				
				# Build each file. We keep track of how many files we've built so that when we're done
				# we can perform the final callback.
				builtFileCount = 0
				
				lib.file.walkSync @inputPath, (path, directories, files) =>
					for fileName in files
						continue if @config.ignoreHiddenFiles and fileName[0] is "."
						
						@buildFile "#{path}/#{fileName}", (error) =>
							errors.push error if error?
							@callback?(errors) if ++builtFileCount is @totalFileCount
	
	
	# Builds the file at the given URL. The callback must be called whenever the file is done building.
	buildFile: (url, callback) ->
		inputUrlInfo  = @getUrlInfo url, @inputPath
		outputUrlInfo = @getOutputUrlInfo inputUrlInfo
		
		if inputUrlInfo.isConcatFile
			@buildConcatFile inputUrlInfo, outputUrlInfo, callback
		else
			input          = lib.fs.readFileSync url
			input          = input.toString() if inputUrlInfo.plugin.fileType is "text"
			renderFunction = if inputUrlInfo.isIndexFile then "renderIndexContent" else "renderContent"
			
			inputUrlInfo.plugin[renderFunction] input, { url: url }, (output = "", data = {}, error) =>
				lib.fs.writeFileSync outputUrlInfo.url, output
				callback error
	
	
	# A helper to build a concat file.
	buildConcatFile: (inputUrlInfo, outputUrlInfo, callback) ->
		urls = @getUrlsForConcatFile inputUrlInfo
		
		# Make sure we actually have some urls. We still want to generate an empty file if we
		# don't, though.
		if urls.length is 0
			lib.exec "touch #{outputUrlInfo.url}", -> callback()
			return
		
		# Gather the files into chunks. Because we can't guarantee that every file uses the same
		# plugin, we can't necessarily compile all of the files at once. Any contiguous series of files
		# that all use the same plugin will be compiled together.
		chunks       = []
		currentChunk = null
		
		for url in urls
			urlInfo = @getUrlInfo url, @inputPath
			input   = lib.fs.readFileSync(url).toString() # TODO: Probably need to check if the file exists.
			
			if urlInfo.plugin is currentChunk?.plugin
				currentChunk.inputs.push input
				currentChunk.urls.push   url
			else
				currentChunk = { plugin: urlInfo.plugin, inputs: [input], urls: [url] }
				chunks.push currentChunk
		
		# Build each chunk.
		chunkOutputs = []
		errors       = []
		
		recursiveBuildChunk = (index) ->
			chunk = chunks[index]
			
			chunk.plugin.renderContentList chunk.inputs, { urls: chunk.urls }, (output, data, error) ->
				chunkOutputs.push output if output?
				errors.push       error  if error?
				
				if ++index < chunks.length
					recursiveBuildChunk index
				else
					lib.fs.writeFileSync outputUrlInfo.url, chunkOutputs.join("\n\n")
					
					if errors.length > 0
						callback errors.join("\n\n")
					else
						callback()
		
		recursiveBuildChunk 0
	
	
	# A helper that returns a list of URLs associated with the given concat file. They will be in
	# the proper order that they should be built in.
	getUrlsForConcatFile: (inputUrlInfo) ->
		result       = []
		relativeUrls = lib.fs.readFileSync(inputUrlInfo.url).toString().split "\n"
		
		# Gather up the ordered list of URLs. We store them as URLs initially because it's easier
		# to check for duplicates that way.
		for relativeUrl in relativeUrls
			relativeUrl = relativeUrl.trim()
			continue if relativeUrl.length is 0 or relativeUrl[0] is "#"
			url = lib.path.join @appPath, relativeUrl
			
			unless lib.path.existsSync url
				@logError "Concat file #{inputUrlInfo.relativeUrl} includes file #{relativeUrl}, which does not exist."
				continue
			
			if lib.fs.lstatSync(url).isDirectory()
				lib.file.walkSync url, (path, directories, files) =>
					for fileName in files
						url = "#{path}/#{fileName}"
						continue if (@config.ignoreHiddenFiles and fileName[0] is ".") or (result.indexOf(url) >= 0)
						result.push url
			else
				result.push url
		
		# Handle require statements in our files.
		orderedResult = result.slice()
		
		for url in result
			dependentUrls = @getDependentUrlsForUrl url
			
			for dependentUrl in dependentUrls
				unless lib.path.existsSync dependentUrl
					relativeUrl          = @getUrlInfo(url).relativeUrl
					dependentRelativeUrl = @getUrlInfo(dependentUrl).relativeUrl
					@logError "File #{relativeUrl} requires file #{dependentRelativeUrl}, which does not exist."
					continue
				
				index          = orderedResult.indexOf url
				dependentIndex = orderedResult.indexOf dependentUrl
				
				if dependentIndex > index
					orderedResult.splice dependentIndex, 1
					orderedResult.splice index, 0, dependentUrl
		
		orderedResult
	
	
	# Returns a list of URLs to the dependent files for the file at the given URL based on any
	# require statements at the top of the file.
	getDependentUrlsForUrl: (url) ->
		reader = new lib.wrench.LineReader url
		result = []
		
		requirePatterns = [
			/^(##?|\/\/)~ +(\S+)$/
			/^(\/\*)~ +(\S+) +\*\/$/
		]
		
		blockSkipPatterns = [
			{ open: /^\/\*/,              close: /\*\//, oneLine: /^\/\*.*\*\/$/    }
			{ open: /^(###$|###[^#].*)/,  close: /###/,  oneLine: /^###[^#]+#{3,}$/ }
		]
		
		lineSkipPattern         = /^(#|\/\/)/
		currentBlockSkipPattern = null
		
		# Go through the lines of the file, reading any require statements until we hit some non-
		# skippable content (i.e., anything that's not a comment).
		while reader.hasNextLine()
			line = reader.getNextLine().trim()
			
			# If we're in a comment block, skip lines until we match the closing pattern.
			if currentBlockSkipPattern?
				currentBlockSkipPattern = null if currentBlockSkipPattern.close.exec(line)?
				continue
			
			# See if we have a require statement on this line.
			requireMatch = null
			
			for requirePattern in requirePatterns
				requireMatch = requirePattern.exec line
				break if requireMatch?
			
			# If we have a require statement, add the dependent file.
			if requireMatch?
				result.push requireMatch[2]
				continue
			
			# See if we have an opening comment block or a one-line block comment.
			hasOneLineBlockSkip = false
			
			for blockSkipPattern in blockSkipPatterns
				if blockSkipPattern.oneLine.exec(line)?
					hasOneLineBlockSkip = true
					break
				else if blockSkipPattern.open.exec(line)?
					currentBlockSkipPattern = blockSkipPattern
					break
			
			# If we have an opening comment block, start ignoring lines until we match the
			# closing pattern.
			continue if hasOneLineBlockSkip or currentBlockSkipPattern?
			
			# Lastly, check if we can skip just this line. Otherwise we're done.
			if line.length is 0 or lineSkipPattern.exec(line)?
				continue
			else
				break
		
		# Convert relative URLs to absolute URLs.
		urlInfo = @getUrlInfo url
		
		for url, index in result
			basePath      = if url[0] is "." then urlInfo.path else @appPath
			result[index] = lib.path.join basePath, url
		
		result
	
	
	# We override this function to add some additional information about the URL.
	getUrlInfo: (url, basePath = @appPath) ->
		info              = super
		info.isConcatFile = info.fileNameComponents[info.fileNameComponents.length - 2] is "concat"
		info.isIndexFile  = info.baseName is "index"
		info.plugin       = @plugins[info.extension] or @defaultPlugin
		info
	
	
	# Takes in a URL info object for an input file and returns a new URL info object based on the
	# output URL.
	getOutputUrlInfo: (inputUrlInfo) ->
		outputPath      = lib.path.join @outputPath, inputUrlInfo.relativePath
		outputBaseName  = inputUrlInfo.baseName.replace ".concat", ""
		outputExtension = if inputUrlInfo.isIndexFile then "html" else inputUrlInfo.plugin.outputExtension or inputUrlInfo.extension
		outputUrl       = "#{outputPath}/#{outputBaseName}"
		outputUrl      += ".#{outputExtension}" if outputExtension
		@getUrlInfo outputUrl, @outputPath


# We only expose the run function.
exports.run = (options) -> (new BuildCommand mode: options.mode).run options
