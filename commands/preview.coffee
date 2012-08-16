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
		
		# Create the preview server.
		server = lib.httpProxy.createServer (request, response, proxy) =>
			params = {request, response, proxy}
			
			# There can be issues if the build folder doesn't exist, so we need to make sure the
			# project is built before a request is handled.
			if lib.fs.existsSync @outputPath
				params.urlInfo = @getRouteUrlInfo request.url
				@handleRequest params
			else
				commands.build.run mode: "preview", callback: (errors) =>
					params.urlInfo = @getRouteUrlInfo request.url
					@handleRequest params
		
		server.listen options.port
		
		address = lib.colors.bold "http://localhost:#{options.port}/"
		console.log "\nRunning a local server at #{address}"
		console.log "Everything will be rebuilt each time the browser is refreshed.\n"
	
	
	# Handles a request. If the request is for an index file, it will rebuild the project.
	handleRequest: (params) ->
		# Modify the URL to route to an index file if necessary.
		params.urlInfo = @getUrlInfo "#{params.urlInfo.url}/index.html" if params.urlInfo.isDirectory
		
		# Serve the response.
		if params.urlInfo.baseName is "index"
			@log "[Build]", "Begin", 1, "yellow"
			
			commands.build.run mode: "preview", callback: (errors) =>
				@log "[Build]", "End", 1, "yellow"
				params.errors = errors if errors.length > 0
				@serveResponse params
		else
			@serveResponse params
	
	
	# Serves a response based on the given parameters. Calls out to one of the helper functions
	# below depending on the content of the params.
	serveResponse: (params) ->
		if params.errors?
			@serveErrors params
		else if lib.fs.existsSync params.urlInfo.url
			@serveFile params
		else if @config.enableProxy
			@serveProxy params
		else
			@serve404 params
	
	# Serves a static file.
	serveFile: (params, delay = @config.simulatedFileDelay) ->
		{request, response, urlInfo} = params
		
		if delay > 0
			@log "[Delay]", "#{request.url} (#{delay}ms)", 2, "cyan"
			setTimeout (=> @serveFile params, 0), delay
		else
			@log "[Serve]", "#{request.url}", 2, "blue"
			response.writeHead 200, "Content-Type": lib.mime.lookup(urlInfo.url)
			response.write lib.fs.readFileSync(urlInfo.url), "binary"
			response.end()
	
	# Serves a proxied route.
	serveProxy: (params, delay = @config.simulatedProxyDelay) ->
		{request, response, proxy, buffer} = params
		
		if delay > 0
			@log "[Delay]", "#{request.url} (#{delay}ms)", 2, "cyan"
			params.buffer = lib.httpProxy.buffer request
			setTimeout (=> @serveProxy params, 0), delay
		else
			@log "[Proxy]", "#{request.url}", 2, "green"
			proxy.proxyRequest request, response,
				host:   @config.proxyHost
				port:   @config.proxyPort
				buffer: buffer
	
	# Takes in a list of errors generated during the build process and serves them with a 500.
	serveErrors: ({response, errors}) ->
		response.writeHead 500, "Content-Type": "text/plain"
		response.write @consolidateErrors errors, "plain"
		response.end()
	
	# Serves a 404 error.
	serve404: ({request, response, urlInfo}) ->
		@log "[Serve]", "#{request.url} (Not Found)", 2, "red"
		response.writeHead 404, "Content-Type": "text/plain"
		response.write "404: File #{urlInfo.url} not found."
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
	log: (label, message, verboseThreshold = 1, labelColor = "white") ->
		timestamp = lib.colors.grey "<#{@getTimestamp()}>"
		label     = lib.colors[labelColor] label
		console.log "#{timestamp} #{label} #{message}" if @verboseLevel >= verboseThreshold
	
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
