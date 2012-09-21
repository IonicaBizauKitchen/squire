##
## classes/squire_directory.coffee
## 
## A class that represents a directory. The app tree is comprised of these and SquireFiles.
##

lib =
	squire: require "../squire"

exports.SquireDirectory = class extends lib.squire.Squire
	constructor: (options = {}) ->
		super
		@path          = options.path
		@publicPath    = options.publicPath
		pathComponents = @path.split "/"
		@name          = pathComponents[pathComponents.length - 1]
		@directories   = {}
		@files         = {}
	
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
	
	walk: (callback) ->
		callback this
		directory.walk callback for name, directory of @directories
