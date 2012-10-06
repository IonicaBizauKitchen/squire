##
## core/url.coffee
## 
## A helper utility class for parsing a URL and providing access to various information about it.
##

lib =
	fs:     require "fs"
	path:   require "path"
	squire: require "../main"
	wrench: require "wrench"

# We need a Squire instance to get things like the output path, plugins, etc.
# TODO: Need to get rid of this. We have no way of setting the mode properly.
squire = new lib.squire.Squire

class Url
	constructor: (@path) ->
	
	Object.defineProperty @prototype, "path",
		get:        -> @_path
		set: (path) ->
			throw "Squire URL requires a defined value for a path; received #{path}." unless path?
			path   = path[0...path.length - 1] if path[-1...] is "/"
			@_path = path
	
	Object.defineProperty @prototype, "basePath", get: ->
		path      = @path
		basePaths = [squire.inputPath, squire.appPath, squire.outputPath]
		return basePath for basePath in basePaths when path.indexOf(basePath) is 0
		return ""
	
	Object.defineProperty @prototype, "exists",             get: -> lib.fs.existsSync @path
	Object.defineProperty @prototype, "isDirectory",        get: -> @exists and lib.fs.lstatSync(@path).isDirectory()
	Object.defineProperty @prototype, "relativePath",       get: -> @path[@basePath.length + 1...]
	Object.defineProperty @prototype, "fileName",           get: -> if @isDirectory then null       else lib.path.basename @path
	Object.defineProperty @prototype, "extension",          get: -> if @isDirectory then null       else lib.path.extname(@fileName)[1..]
	Object.defineProperty @prototype, "directory",          get: -> if @isDirectory then @path      else lib.path.join @path, ".."
	Object.defineProperty @prototype, "relativeDirectory",  get: -> if @isDirectory then @directory else @directory[@basePath.length + 1...]
	Object.defineProperty @prototype, "components",         get: -> @path.split("/")[1...]
	Object.defineProperty @prototype, "relativeComponents", get: -> @relativePath.split "/"
	Object.defineProperty @prototype, "fileNameComponents", get: -> @fileName?.split "."
	
	Object.defineProperty @prototype, "baseName", get: ->
		if @isDirectory
			lib.path.basename @path
		else
			{fileName} = this
			fileName[0...fileName.length - @extension.length - 1]
	
	Object.defineProperty @prototype, "isConcatFile", get: -> @fileNameComponents[1] is "concat"
	Object.defineProperty @prototype, "isIndexFile",  get: -> @baseName is "index"
	Object.defineProperty @prototype, "isEcoFile",    get: -> @extension is "eco"
	
	# Returns a list of absolute paths to the dependent files for this URL based on require
	# statements.
	# TODO: This should probably be on the file.
	Object.defineProperty @prototype, "dependentPaths", get: ->
		reader = new lib.wrench.LineReader @path
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
		
		# Close the file from the line reader.
		lib.fs.closeSync reader.fd
		
		# Convert relative paths to absolute paths.
		# TODO: I think this is wrong.
		url = new Url @path
		
		for path, index in result
			basePath      = if path[0] is "." then url.path else squire.appPath
			result[index] = lib.path.join basePath, path
		
		result
	
	# Returns a new URL by joining this path with the given relative path.
	join: (relativePath) ->
		new Url (lib.path.join @path, relativePath)
	
	# Return the path when converting to string.
	toString: -> @path

# Expose class.
exports.Url = Url
