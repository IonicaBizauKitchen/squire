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
		@verboseLevel = options.verbose
		
		server = lib.httpProxy.createServer (request, response, proxy) =>
			@handleRequest request, response, proxy, @getRouteUrlInfo(request.url)
		
		server.listen options.port
		
		address = lib.colors.bold "http://localhost:#{options.port}/"
		console.log "\nRunning a local server at #{address}"
		console.log "Everything will be rebuilt each time the browser is refreshed.\n"
	
	
	# Handles a request. If the request is for an index file, it will rebuild the project.
	handleRequest: (request, response, proxy, urlInfo) ->
		urlInfo = @getUrlInfo "#{urlInfo.url}/index.html" if urlInfo.isDirectory
		
		if urlInfo.baseName is "index"
			@log "[Build]", 1
			
			commands.build.run mode: "preview", callback: (errors) =>
				if errors.length > 0
					@serveErrors request, response, proxy, errors
				else
					@serveFile request, response, proxy, urlInfo
		else
			@serveFile request, response, proxy, urlInfo
	
	
	# Serves up the file at the given URL.
	serveFile: (request, response, proxy, urlInfo) ->
		if lib.fs.existsSync urlInfo.url
			@log "[Serve] #{urlInfo.relativeUrl}", 2
			response.writeHead 200, "Content-Type": lib.mime.lookup(urlInfo.url)
			response.write lib.fs.readFileSync(urlInfo.url), "binary"
			response.end()
		else if @config.enableProxy
			@log "[Proxy] #{urlInfo.relativeUrl}", 2
			proxy.proxyRequest request, response, host: @config.proxyHost, port: @config.proxyPort
		else
			@log "[Serve] #{urlInfo.relativeUrl} (Not Found)", 2
			response.writeHead 404, "Content-Type": "text/plain"
			response.write "404: File #{urlInfo.url} not found."
			response.end()
	
	
	# Takes in a list of errors generated during the build process and serves them with a 500.
	serveErrors: (request, response, proxy, errors) ->
		response.writeHead 500, "Content-Type": "text/plain"
		response.write @consolidateErrors errors, "plain"
		response.end()
	
	
	# Does some processing of a given request URL and returns a URL info object.
	getRouteUrlInfo: (url) ->
		rewrites      = @config.routeRewrites or []
		urlComponents = url.split "/"
		
		for rewrite in rewrites
			{from, to}     = rewrite
			from           = from[0...from.length - 1] if from[from.length - 1] is "/"
			fromComponents = from.split "/"
			matches        = true
			keys           = {}
			
			if fromComponents.length is urlComponents.length
				for fromComponent, index in fromComponents
					urlComponent = urlComponents[index]
					
					if fromComponent[0] is ":"
						key       = fromComponent[1..]
						keys[key] = urlComponent
					else if fromComponent isnt urlComponent
						matches = false
						break
			else
				matches = false
			
			if matches
				url = to
				url = url.replace ":#{key}", value for key, value of keys
				break
		
		url = lib.path.join @outputPath, url
		@getUrlInfo url, @outputPath
	
	
	# A log helper that filters messages based on a verbose level.
	log: (message, verboseThreshold = 1) ->
		console.log "<#{@getTimestamp()}> #{message}" if @verboseLevel >= verboseThreshold
	
	
	# Returns a formatted timestamp for the current time.
	getTimestamp: ->
		date    = new Date
		hours   = date.getHours()
		minutes = date.getMinutes()
		seconds = date.getSeconds()
		hours   = "0#{hours}"   if hours < 10
		minutes = "0#{minutes}" if minutes < 10
		seconds = "0#{seconds}" if seconds < 10
		
		"#{hours}:#{minutes}:#{seconds}"


# We only expose the run function.
exports.run = (options) -> (new PreviewCommand mode: "preview").run options
