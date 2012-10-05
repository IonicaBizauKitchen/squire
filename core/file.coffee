##
## core/file.coffee
## 
## A class that represents a file. The app tree is comprised of these and SquireDirectories.
##

lib =
	_:               require "underscore"
	file:            require "file"
	fs:              require "fs"
	makeSynchronous: require "make-synchronous"
	merge:           require "deepmerge"
	path:            require "path"
	squire:          require "../main"

class File extends lib.squire.Squire
	constructor: ({path} = {}) ->
		super
		@url = new lib.squire.Url path
	
	# The raw content of the file before it gets processed.
	Object.defineProperty @prototype, "rawContent", get: ->
		if @plugin?.contentType is "text" then @loadTextFile @url.path else @loadFile @url.path
	
	# A getter for the processed content. It will load and process the content on demand. The
	# content gets cached for performance. If you need to rebuild the file, call reloadContent().
	Object.defineProperty @prototype, "content",
		get: ->
			@build() if @_content is undefined
			@_content
		
		set: (@_content) ->
	
	# A getter for the file's data. Works exactly the same as the content.
	Object.defineProperty @prototype, "data",
		get: ->
			@build() if @_data is undefined
			@_data
		
		set: (@_data) ->
	
	# Same thing but for errors.
	Object.defineProperty @prototype, "errors",
		get: ->
			@build() if @_errors is undefined
			@_errors
		
		set: (@_errors) ->
	
	# The file's plugin. Just proxies to the URL's plugin for convenience.
	Object.defineProperty @prototype, "plugin", get: -> @url?.plugin
	
	# Returns the list of plugins that can post-process this file.
	Object.defineProperty @prototype, "postProcessPlugins", get: ->
		plugins   = []
		extension = @url.extension
		
		plugin for plugin in @plugins when extension in (plugin.postProcessExtensions or [plugin.outputExtension])
	
	# Returns the parent directory.
	Object.defineProperty @prototype, "parent", get: ->
		relativeDirectory = @url.directory[@app.url.path.length...]
		@app?.getPath(relativeDirectory).url.path
	
	# Resets the content cache so that the next time content is requested it will be rebuilt.
	reloadContent: ->
		delete @_content
		delete @_data
		delete @_errors
	
	# Builds the file at our path and returns the built content. This is only needed internally --
	# generally you should use the "content" property to retrieve the content.
	build: ->
		# Reset data and grab the raw content.
		@errors  = []
		@data    = {}
		@content = @rawContent
		
		# Pre-process the raw content.
		@preProcessContent()
		
		# Build the file depending on its type.
		if @url.isConcatFile
			@buildConcatFile()
		else
			@buildStandardFile()
		
		# Post-process the content.
		@postProcessContent()
	
	# Pre-processes the raw content and sets it to @content.
	preProcessContent: ->
		return null unless @content? and @errors.length is 0
		
		# For now we just parse eco files.
		@parseEcoContent() if @url.isEcoFile
	
	# Builds a concat file.
	buildConcatFile: ->
		return null unless @content? and @errors.length is 0
		
		paths = @getConcatPaths()
		
		# Make sure we actually have some paths. We still want to generate an empty file if we
		# don't, though.
		return "" if paths.length is 0
		
		# Gather the files into chunks. Because we can't guarantee that every file uses the same
		# plugin, we can't necessarily compile all of the files at once. Any contiguous series of files
		# that all use the same plugin will be compiled together.
		chunks       = []
		currentChunk = null
		
		for path in paths
			url   = new lib.squire.Url path, @inputPath
			input = @loadTextFile path
			
			if url.plugin is currentChunk?.plugin
				currentChunk.inputs.push input
				currentChunk.paths.push  path
			else
				currentChunk = { plugin: url.plugin, inputs: [input], paths: [path] }
				chunks.push currentChunk
		
		# Build each chunk.
		chunkOutputs = []
		
		for chunk in chunks
			lib.makeSynchronous chunk.plugin, chunk.plugin.renderContentList, chunk.inputs, { paths: chunk.paths }, (output, data = {}, errors = []) =>
				chunkOutputs.push output if output?
				@errors = @errors.concat errors
				@data   = lib.merge @data, data
		
		# Set the content to the joined chunks.
		@content = if chunkOutputs.length > 0 then chunkOutputs.join "\n\n" else null
	
	# Builds a regular file.
	buildStandardFile: ->
		return null unless @content? and @errors.length is 0
		
		renderFunction = if @url.isIndexFile then "renderIndexContent" else "renderContent"
		
		lib.makeSynchronous @plugin, @plugin[renderFunction], @content, { path: @url.path }, (output, data = {}, errors = []) =>
			@content = output
			@errors  = @errors.concat errors
			@data    = lib.merge @data, data
	
	# Post-processes the content.
	postProcessContent: ->
		return null unless @content? and @errors.length is 0
		
		# Post-process with each plugin.
		for plugin in @postProcessPlugins
			break if @errors.length > 0
			
			lib.makeSynchronous plugin, plugin.postProcessContent, @content, {}, (output, data = {}, errors = []) =>
				@content = output
				@errors  = @errors.concat errors
				@data    = lib.merge @data, data
	
	# Runs the current content through eco.
	parseEcoContent: ->
		return null unless @content? and @errors.length is 0
		
		try
			@content = lib.eco.render @content.toString(), app: @app, config: @config, _: lib._
		catch error
			@errors.push new lib.Error message: "There was an error while compiling your eco file:", details: error.toString(), path: path
			@content = null
	
	# If this is a concat file, this will return the list of associated paths. They will be in the
	# proper order that they should be built in.
	getConcatPaths: ->
		return null unless @content? and @url.exists and @url.isConcatFile
		
		result        = []
		relativePaths = @content.trim().split "\n"
		
		# Gather up the ordered list of paths.
		for relativePath in relativePaths
			relativePath = relativePath.trim()
			relativePath = relativePath[...-1] if relativePath[-1...] is "/"
			
			# Skip empty lines and comments.
			continue if relativePath.length is 0 or relativePath[0] is "#"
			
			# Lines preceded with an exclamation point will remove files, otherwise we add them.
			if relativePath[0] is "!"
				path = lib.path.join @appPath, relativePath[1..]
				
				if lib.fs.lstatSync(path).isDirectory()
					lib.file.walkSync path, (localPath, directories, files) =>
						for fileName in files
							index = result.indexOf "#{localPath}/#{fileName}"
							result.splice index, 1 if index >= 0
				else
					index = result.indexOf path
					result.splice index, 1 if index >= 0
			else
				path = lib.path.join @appPath, relativePath
				
				unless lib.fs.existsSync path
					@logError "Concat file #{@url.relativePath} includes file #{relativePath}, which does not exist."
					continue
				
				if lib.fs.lstatSync(path).isDirectory()
					lib.file.walkSync path, (path, directories, files) =>
						for fileName in files
							localPath = "#{path}/#{fileName}"
							continue if (@config.ignoreHiddenFiles and fileName[0] is ".") or (result.indexOf(localPath) >= 0)
							result.push localPath
				else
					result.splice result.indexOf(path), 1 if result.indexOf(path) >= 0
					result.push path
		
		# Reorder the result based on require statements in our files.
		orderedResult = result.slice()
		
		for path in result
			url            = new lib.squire.Url path
			dependentPaths = url.dependentPaths
			
			for dependentPath in dependentPaths
				unless lib.fs.existsSync dependentPath
					relativePath          = url.relativePath
					dependentRelativePath = (new lib.squire.Url dependentPath).relativePath
					@logError "File #{relativePath} requires file #{dependentRelativePath}, which does not exist."
					continue
				
				index          = orderedResult.indexOf path
				dependentIndex = orderedResult.indexOf dependentPath
				
				if dependentIndex > index
					orderedResult.splice dependentIndex, 1
					orderedResult.splice index, 0, dependentPath
		
		orderedResult
	
	# Concatenates all of the errors in the file and returns them.
	consolidateErrors: (type = "fancy") ->
		(error["#{type}Message"] for error in @errors).join "\n\n"

# Expose class.
exports.File = File
