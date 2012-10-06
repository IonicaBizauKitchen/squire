##
## core/directory.coffee
## 
## A class that represents a directory. The app tree is comprised of these and Files.
##

lib =
	fs:     require "fs"
	squire: require "../main"

class Directory extends lib.squire.Squire
	constructor: ({path} = {}) ->
		super
		@url = new lib.squire.Url path
		@populateContents()
	
	# An accessor for the errors of all files contained in this directory and all directories
	# underneath it.
	Object.defineProperty @prototype, "errors", get: ->
		errors = []
		errors = errors.concat(file.errors)      for name, file      of @files
		errors = errors.concat(directory.errors) for name, directory of @directories
		errors
	
	# Sets the files and directories of the directory. Because directories populate their contents
	# on creation, subdirectories will be populated recursively.
	populateContents: ->
		# Reset the existing directories and files.
		@directories = {}
		@files       = {}
		
		# Make sure this is actually an existing directory.
		return unless @url.isDirectory
		
		# Enumerate the files in this directory.
		for name in lib.fs.readdirSync @url.path
			# Skip hidden files.
			continue if @config.ignoreHiddenFiles and name[0] is "."
			
			# Create a directory or file.
			path        = "#{@url.path}/#{name}"
			isDirectory = lib.fs.existsSync(path) and lib.fs.lstatSync(path).isDirectory()
			
			if isDirectory
				@directories[name] = new lib.squire.Directory { path, mode: @mode }
			else
				@files[name] = new lib.squire.File { path, mode: @mode }
	
	# Returns the file or directory at the given path, relative to this directory. For example, you
	# can do something like `directory.getPath "path/to/my/file.txt"` to get that file.
	getPath: (path) ->
		path = path[1..] while path[0] is "/"
		
		if path.length is 0
			this
		else
			node           = this
			pathComponents = path.split "/"
			
			for component, index in pathComponents
				nextNode = node.directories[component]
				nextNode = node.files[component] if not nextNode? and index is pathComponents.length - 1
				node     = nextNode
				break unless node?
			
			node
	
	# Perform a synchronous, recursive, depth-first search enumeration of all the child
	# directories.
	walk: (callback) ->
		callback this
		directory.walk callback for name, directory of @directories
	
	# Concatenates all of the errors in the directory and returns them.
	consolidateErrors: (type = "fancy") ->
		messages = []
		
		for name, file of @files
			message = file.consolidateErrors type
			messages.push message if message.length > 0
		
		for name, directory of @directories
			message = directory.consolidateErrors type
			messages.push message if message.length > 0
		
		messages.join "\n\n"

# Expose class.
exports.Directory = Directory
