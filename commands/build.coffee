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
	cson:   require "cson"
	merge:  require "deepmerge"
	file:   require "file"
	wrench: require "wrench"
	bolt:   require "../bolt"


command =
	defaultConfig:
		global:
			appDirectory:      "app"
			inputDirectory:    "content"
			outputDirectory:   "build"
			tempDirectory:     ".temp"
			ignoreHiddenFiles: true
		preview:
			minify: false
		build:
			minify: true
	
	
	# The entry point to the command.
	run: (options) ->
		# Gather up config values.
		@rootPath  = process.env.PWD
		userConfig = lib.cson.parseFileSync("#{@rootPath}/config/bolt.cson") or {}
		@config    = lib.merge @defaultConfig, userConfig
		@config    = lib.merge @config.global, @config[options.mode]
		
		# Store some useful paths.
		@boltPath       = lib.path.join __dirname, ".."
		@appPath        = "#{@rootPath}/#{@config.appDirectory.trim()}"
		@inputPath      = "#{@appPath}/#{@config.inputDirectory.trim()}"
		@outputPath     = "#{@rootPath}/#{@config.outputDirectory.trim()}"
		@tempPath       = "#{@rootPath}/#{@config.tempDirectory.trim()}"
		@callback       = options.callback
		@totalFileCount = 0
		
		# Do the stuff to make the thing.
		@gatherContent()
		@loadPlugins()
		@buildFiles()
	
	
	# Gathers up all of the contents of the app directory into an object.
	gatherContent: ->
		@appContent = {}
		
		lib.file.walkSync @appPath, (path, directories, files) =>
			relativePathComponents = path[@appPath.length + 1..].split "/"
			directoryContent       = @appContent
			
			for component in relativePathComponents
				directoryContent[component] = {} unless directoryContent[component]?
				directoryContent = directoryContent[component]
			
			for fileName in files
				continue if @config.ignoreHiddenFiles and fileName[0] is "."
				
				# TODO: Add more info here.
				directoryContent[fileName] =
					name: fileName
	
	
	# Loads all of the plugins specified by the user.
	loadPlugins: ->
		DefaultPlugin  = require("#{@boltPath}/plugins/default.coffee").Plugin
		@defaultPlugin = new DefaultPlugin
		@plugins       = {}
		
		return unless @config.plugins?
		
		for pluginId in @config.plugins
			plugin = null
			
			paths = [
				"#{@rootPath}/plugins/#{pluginId}.coffee"
				"#{@boltPath}/plugins/#{pluginId}.coffee"
				"bolt-#{pluginId}"
			]
			
			for path in paths
				try
					Plugin            = require(path).Plugin
					plugin            = new Plugin
					plugin.appContent = appContent
					# TODO: Set plugin.config if we have, for example, a config/#{pluginId}.cson file.
					break
				catch error
					# TODO: Sometimes this is an actual error with the plugin itself. We need to come up with a better system so we can surface those errors properly.
					continue
			
			# TODO: Use standard error logging.
			unless plugin?
				lib.bolt.util.logError "Plugin #{pluginId} was included but does not exist."
				continue
			
			unless plugin.inputExtensions?.length > 0
				lib.bolt.util.logError "Plugin #{pluginId} does not define any associated input extensions."
				continue
			
			@plugins[extension] = plugin for extension in plugin.inputExtensions
	
	
	# Runs through the content tree, building each file.
	buildFiles: ->
		# Start by counting the total number of files.
		lib.file.walkSync @inputPath, (path, directories, files) =>
			for fileName in files
				@totalFileCount++ unless @config.ignoreHiddenFiles and fileName[0] is "."
		
		# Clean the temp and build folders. Since we're going to be running rm -rf, we do a little
		# bit of sanity checking to help prevent catastrophic occurrences.
		if @outputPath.indexOf(@rootPath) is 0 and @tempPath.indexOf(@rootPath) is 0
			lib.exec "rm -rf #{@outputPath} #{@tempPath}", (error, stdout, stderr) =>
				throw error if error?
				lib.fs.mkdirSync @tempPath,  0o0755
				lib.fs.mkdirSync @outputPath, 0o0755
				
				# Fill up the temp and output paths with the directory structure of the input path.
				lib.file.walkSync @inputPath, (path, directories, files) =>
					relativePath = path[@inputPath.length + 1..]
					tempPath     = "#{@tempPath}/#{relativePath}"
					outputPath   = "#{@outputPath}/#{relativePath}"
					
					for directoryName in directories
						lib.fs.mkdirSync "#{tempPath}/#{directoryName}" 
						lib.fs.mkdirSync "#{outputPath}/#{directoryName}"
				
				# Build each file. We keep track of how many files we've built so that when we're done
				# we can remove the temp folder and perform the final callback.
				builtFileCount = 0
				
				lib.file.walkSync @inputPath, (path, directories, files) =>
					for fileName in files
						continue if @config.ignoreHiddenFiles and fileName[0] is "."
						
						@buildFile "#{path}/#{fileName}", =>
							if ++builtFileCount is @totalFileCount
								lib.exec "rm -rf #{@tempPath}", -> @callback?()
	
	
	# Builds the file at the given URL. The callback must be called whenever the file is done building.
	buildFile: (url, callback) ->
		inputUrlInfo  = @getUrlInfo url
		outputUrlInfo = @getOutputUrlInfo inputUrlInfo
		
		if inputUrlInfo.isConcatFile
			@buildConcatFile inputUrlInfo, outputUrlInfo, callback
		else if inputUrlInfo.isIndexFile
			inputUrlInfo.plugin.buildIndexFile inputUrlInfo.url, outputUrlInfo.url, callback
		else
			inputUrlInfo.plugin.buildFile inputUrlInfo.url, outputUrlInfo.url, callback
	
	
	# A helper to build a concat file.
	buildConcatFile: (inputUrlInfo, outputUrlInfo, callback) ->
		urls        = @getUrlsForConcatFile inputUrlInfo
		tempUrlInfo = @getTempUrlInfo outputUrlInfo
		
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
			urlInfo = @getUrlInfo url
			
			if urlInfo.plugin is currentChunk?.plugin
				currentChunk.urls.push url
			else
				currentChunk = { plugin: urlInfo.plugin, urls: [url] }
				chunks.push currentChunk
		
		# Build each chunk.
		chunkUrls       = []
		builtChunkCount = 0
		
		for chunk, index in chunks
			chunkFileName = inputUrlInfo.relativeUrl.replace(/\//g, "_")
			chunkUrl      = "#{tempUrlInfo.url}_#{index}"
			
			chunkUrls.push chunkUrl
			
			chunk.plugin.buildFiles chunk.urls, chunkUrl, =>
				(lib.bolt.util.combineFiles(chunkUrls, outputUrlInfo.url); callback()) if ++builtChunkCount is chunks.length
	
	
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
				lib.bolt.util.logError "Concat file #{inputUrlInfo.relativeUrl} includes file #{relativeUrl}, which does not exist."
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
					relativeUrl          = @getUrlInfo(url, @appPath).relativeUrl
					dependentRelativeUrl = @getUrlInfo(dependentUrl, @appPath).relativeUrl
					lib.bolt.util.logError "File #{relativeUrl} requires file #{dependentRelativeUrl}, which does not exist."
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
			{ open: /^\/\*/, close: /\*\//, oneLine: /^\/\*.*\*\/$/    }
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
					console.log "oneline blocky..."
					hasOneLineBlockSkip = true
					break
				else if blockSkipPattern.open.exec(line)?
					console.log "MEGA blocky"
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
		urlInfo = lib.bolt.util.getUrlInfo url, @appPath
		
		for url, index in result
			basePath      = if url[0] is "." then urlInfo.path else @appPath
			result[index] = lib.path.join basePath, url
		
		result
	
	
	# A proxy function to the normal util function of the same name that adds some additional
	# useful information.
	getUrlInfo: (url, basePath = @inputPath) ->
		info                        = lib.bolt.util.getUrlInfo url
		info.relativePath           = info.path[basePath.length + 1..]
		info.relativeUrl            = if info.relativePath then "#{info.relativePath}/#{info.fileName}" else info.fileName
		info.relativePathComponents = info.relativePath.split "/"
		info.isConcatFile           = info.fileNameComponents[info.fileNameComponents.length - 2] is "concat"
		info.isIndexFile            = info.baseName is "index"
		info.plugin                 = @plugins[info.extension] or @defaultPlugin
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
	
	
	# Takes in a URL info object for an output file and returns a new URL info object based on the
	# temporary URL.
	getTempUrlInfo: (outputUrlInfo) ->
		@getUrlInfo "#{@tempPath}/#{outputUrlInfo.relativeUrl}", @tempPath


# We only expose the run function.
exports.run = (options) -> command.run options
