##
## commands/preview.coffee
## 
## This contains the implementation of the preview command.
##

lib =
	colors:    require "colors"
	fs:        require "fs"
	httpProxy: require "http-proxy"
	mime:      require "mime"
	path:      require "path"
	squire:    require "../main"
	watchr:    require "watchr"

commands =
	build: require "./build"

class PreviewCommand extends lib.squire.Squire
	# Whether or not we're currently building. Requests that come in during building will wait
	# until building is done before responding.
	isBuilding: false
	
	# If files change while we're in the middle of building, this flag will be set so that we know
	# to rebuild after the end of the current build.
	needsRebuild: false
	
	# The error message returned from the most recent build. Whenever errors are present (that is,
	# when the length of the error message is > 0), all requests will return a 500 with the
	# message.
	errorMessage: ""
	
	# Requests that come in while we're building don't execute immediately -- we need to wait until
	# we're done building before we respond -- so we queue them up here so that we can respond when
	# we're done building.
	queuedRequestParams: []
	
	# The entry point into the command.
	run: (options) ->
		# Grab some goodies.
		@verboseLevel = options.verbose
		@port         = options.port
		
		# Perform an initial build.
		@build => @handleRequest params for params in @queuedRequestParams
		
		# Watch files and set up the file server.
		@watchFiles()
		@runServer()
		
		# Make some loggies.
		address = lib.colors.bold "http://localhost:#{options.port}/"
		console.log "\nRunning a local server at #{address}"
		console.log "Everything will be rebuilt each time the browser is refreshed.\n"
	
	# Set up a file watcher for input changes.
	watchFiles: ->
		lib.watchr.watch
			path:              @appPath
			ignoreHiddenFiles: @config.ignoreHiddenFiles
			
			# Rebuild whenever something changes. There's a lot of room for improvement here -- in
			# most cases we don't actually need to rebuild the entire app whenever a single file
			# changes. However, every file can potentially be dependent on any other file (many
			# plugins provide access to the app tree), and we don't have a way to get the
			# dependencies of a file, so we just rebuild the whole app to be safe.
			listener: (eventName, path, currentStat, previousStat) =>
				# If we're already building, we're going to need to rebuild again once the current
				# build is done. Otherwise we can initiate a build.
				if @isBuilding
					@needsRebuild = true
				else
					start = Date.now()
					@log "[Build]", "Begin", 1, "yellow"
					
					@build =>
						duration = (Date.now() - start) / 1000.0
						@log "[Build]", "End (#{duration}s)", 1, "yellow"
						@handleRequest params for params in @queuedRequestParams
	
	# Sets up the file server.
	runServer: ->
		server = lib.httpProxy.createServer (request, response, proxy) =>
			params = { request, response, proxy, url: @getRouteUrl request.url }
			
			# If we're building, we need to queue up the request to respond after we're done
			# building. Otherwise we respond immediately.
			if @isBuilding
				@queuedRequestParams.push params
			else
				@handleRequest params
		
		server.listen @port
	
	# A little helper to build the project.
	build: (callback) ->
		# Reset stuff and build.
		@isBuilding   = true
		@errorMessage = ""
		
		commands.build.run mode: "preview", shouldLogErrors: false, callback: =>
			# Start over if we need to rebuild.
			if @needsRebuild
				@needsRebuild = false
				@build callback
				return
			
			# Make note of errors and reset flags.
			@errorMessage = @app.getPath(@config.inputDirectory).consolidateErrors "plain"
			@isBuilding   = @needsRebuild = false
			
			# Call the callback.
			callback?()
	
	# Handles a request. Calls out to one of the helper functions below depending on the content of
	# the params.
	handleRequest: (params) ->
		if @errorMessage?.length > 0
			@serveErrors params
		else if params.url.exists
			@serveFile params
		else if @config.enableProxy
			@serveProxy params
		else
			@serve404 params
	
	# Serves a static file.
	serveFile: (params, delay = @config.simulatedFileDelay) ->
		{request, response, url} = params
		
		if delay > 0
			@log "[Delay]", "#{request.url} (#{delay}ms)", 2, "cyan"
			setTimeout (=> @serveFile params, 0), delay
		else
			@log "[Serve]", "#{request.url}", 2, "blue"
			response.writeHead 200, "Content-Type": lib.mime.lookup(url.path)
			response.write lib.fs.readFileSync(url.path), "binary"
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
	serveErrors: ({response}) ->
		response.writeHead 500, "Content-Type": "text/plain"
		response.write @errorMessage
		response.end()
	
	# Serves a 404 error.
	serve404: ({request, response, url}) ->
		@log "[Serve]", "#{request.url} (Not Found)", 2, "red"
		response.writeHead 404, "Content-Type": "text/plain"
		response.write "404: File #{url.path} not found."
		response.end()
	
	# Does some processing of a given request path and returns a URL object.
	getRouteUrl: (path) ->
		rewrites       = @config.routeRewrites or []
		pathComponents = path.split "/"
		
		# Handle route rewrites.
		for rewrite in rewrites
			{from, to}     = rewrite
			from           = from[0...from.length - 1] if from[from.length - 1] is "/"
			fromComponents = from.split "/"
			matches        = true
			keys           = {}
			
			if fromComponents.length is pathComponents.length
				for fromComponent, index in fromComponents
					pathComponent = pathComponents[index]
					
					if fromComponent[0] is ":"
						key       = fromComponent[1..]
						keys[key] = pathComponent
					else if fromComponent isnt pathComponent
						matches = false
						break
			else
				matches = false
			
			if matches
				path = to
				path = path.replace ":#{key}", value for key, value of keys
				break
		
		url = new lib.squire.Url lib.path.join(@outputPath, path)
		url = new lib.squire.Url "#{url.path}/index.html" if url.isDirectory
		url
	
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
