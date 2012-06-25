##
## commands/preview.coffee
## 
## This contains the implementation of the preview command.
##

lib =
	fs:        require "fs"
	httpProxy: require "http-proxy"
	path:      require "path"
	squire:    require "../squire"
	colors:    require "colors"
	mime:      require "mime"

commands =
	build: require "./build"


class PreviewCommand extends lib.squire.Squire
	# The entry point to the command.
	run: (options) ->
		server = lib.httpProxy.createServer (request, response, proxy) =>
			url = lib.path.join @outputPath, request.url
			@handleRequest request, response, proxy, @getUrlInfo(url, @outputPath)
		
		server.listen options.port
		
		address = lib.colors.bold "http://localhost:#{options.port}/"
		console.log "\nRunning a local server at #{address}"
		console.log "Everything will be rebuilt each time the browser is refreshed.\n"
	
	
	# Handles a request. If the request is for an index file, it will rebuild the project.
	handleRequest: (request, response, proxy, urlInfo) ->
		urlInfo = @getUrlInfo "#{urlInfo.url}/index.html" if urlInfo.isDirectory
		
		if urlInfo.baseName is "index"
			commands.build.run mode: "preview", callback: (errors) =>
				if errors.length > 0
					@serveErrors request, response, proxy, errors
				else
					@serveFile request, response, proxy, urlInfo
		else
			@serveFile request, response, proxy, urlInfo
	
	# Serves up the file at the given URL.
	serveFile: (request, response, proxy, urlInfo) ->
		if lib.path.existsSync urlInfo.url
			response.writeHead 200, "Content-Type": lib.mime.lookup(urlInfo.url)
			response.write lib.fs.readFileSync(urlInfo.url), "binary"
			response.end()
		else if @config.enableProxy
			proxy.proxyRequest request, response, host: @config.proxyHost, port: @config.proxyPort
		else
			response.writeHead 404, "Content-Type": "text/plain"
			response.write "404: File #{urlInfo.url} not found."
			response.end()
	
	# Takes in a list of errors generated during the build process and serves them with a 500.
	serveErrors: (request, response, proxy, errors) ->
		response.writeHead 500, "Content-Type": "text/plain"
		response.write @consolidateErrors errors, "plain"
		response.end()

# We only expose the run function.
exports.run = (options) -> (new PreviewCommand mode: "preview").run options
