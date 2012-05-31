##
## commands/preview.coffee
## 
## This contains the implementation of the preview command.
##

lib =
	fs:   require "fs"
	http: require "http"
	path: require "path"
	url:  require "url"
	exec: require("child_process").exec

commands =
	build: require "./build"


exports.run = (options) ->
	server = lib.http.createServer (request, response) ->
		path = lib.url.parse(request.url).pathname
		
		handleRequest request, response,
			path:           path
			directory:      lib.path.dirname path
			fileName:       lib.path.basename path
			extension:      lib.path.extname path
			components:     path.split("/")[1..]
			fileComponents: lib.path.basename(path).split "."
	
	server.listen options.port
	
	console.log "\nRunning a local server at http://localhost:#{options.port}/"
	console.log "Everything will be recompiled every time the browser is refreshed."


handleRequest = (request, response, fileInfo) ->
	response.writeHead 200, "Content-Type": "text/plain"
	response.write "Yeehaw!\n"
	response.end()
	
	# path.exists filename, (exists) ->
	# 	if !exists or fs.statSync(filename).isDirectory()
	# 		response.writeHead 404, "Content-Type": "text/plain"
	# 		response.write "404: File #{filename} not found."
	# 		response.end()
	# 		return
		
	# 	fs.readFile filename, "binary", (error, file) ->
	# 		if error?
	# 			response.writeHead 500, "Content-Type": "text/plain"
	# 			response.write error + "\n"
	# 			response.end()
	# 			return
			
	# 		# If there is a handler for our file extension, run that. Otherwise just serve the file
	# 		# directly.
	# 		extension = filename.slice filename.lastIndexOf(".") + 1
	# 		handler   = requestHandlers[extension]
			
	# 		if handler?
	# 			handler file, filename, request, response
	# 		else
	# 			# TODO: Set the content type.
	# 			response.writeHead 200
	# 			response.write file, "binary"
			
	# 		response.end()
