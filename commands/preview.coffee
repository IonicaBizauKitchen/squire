##
## commands/preview.coffee
## 
## This contains the implementation of the preview command.
##

lib =
	fs:     require "fs"
	http:   require "http"
	path:   require "path"
	squire: require "../squire"
	colors: require "colors"
	mime:   require "mime"

commands =
	build: require "./build"

class PreviewCommand extends lib.squire.Squire
	# The entry point to the command.
	run: (options) ->
		server = lib.http.createServer (request, response) =>
			url = lib.path.join @outputPath, request.url
			@handleRequest request, response, @getUrlInfo(url, @outputPath)
		
		server.listen options.port
		
		address = lib.colors.bold "http://localhost:#{options.port}/"
		console.log "\nRunning a local server at #{address}"
		console.log "Everything will be rebuilt each time the browser is refreshed.\n"
	
	
	# Handles a request. If the request is for an index file, it will rebuild the project.
	handleRequest: (request, response, urlInfo) ->
		urlInfo = @getUrlInfo "#{urlInfo.url}/index.html" if urlInfo.isDirectory
		
		if urlInfo.baseName is "index"
			commands.build.run mode: "preview", callback: (errors) =>
				if errors.length > 0
					@serveErrors request, response, errors
				else
					@serveFile request, response, urlInfo
		else
			@serveFile request, response, urlInfo
	
	# Serves up the file at the given URL.
	serveFile: (request, response, urlInfo) ->
		if lib.path.existsSync(urlInfo.url)
			# TODO: We need to bubble up errors from the build command.
			response.writeHead 200, "Content-Type": lib.mime.lookup(urlInfo.url)
			response.write lib.fs.readFileSync(urlInfo.url), "binary"
		else
			response.writeHead 404, "Content-Type": "text/plain"
			response.write "404: File #{urlInfo.url} not found."
		
		response.end()
	
	# Takes in a list of errors generated during the build process and serves them with a 500.
	serveErrors: (request, response, errors) ->
		response.writeHead 500, "Content-Type": "text/plain"
		response.write @consolidateErrors errors, "plain"
		response.end()

# We only expose the run function.
exports.run = (options) -> (new PreviewCommand mode: "preview").run options
