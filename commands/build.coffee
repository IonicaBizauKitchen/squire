##
## commands/build.coffee
## 
## This contains the implementation of the build command.
##

lib =
	fibers: require "fibers"
	file:   require "file"
	fs:     require "fs"
	squire: require "../main"
	wrench: require "wrench"

class BuildCommand extends lib.squire.Squire
	# The entry point to the command.
	run: (options) ->
		options.shouldLogErrors ?= true
		
		# Make sure we've got our directories set up properly.
		unless lib.fs.existsSync @appPath
			lib.squire.Error.log "Configured application path #{@appPath} does not exist."
			return
		
		unless lib.fs.existsSync @inputPath
			lib.squire.Error.log "Configured input path #{@inputPath} does not exist."
			return
		
		# Clean out the build folder.
		@cleanBuildFolder()
		
		# Construct the app tree.
		@app           = new lib.squire.Directory mode: @mode, path: @appPath
		inputDirectory = @app.getPath @config.inputDirectory
		
		# Walk the input directory and spit out each file.
		inputDirectory.walk (directory) ->
			for name, file of directory.files
				outputUrl = file.outputUrl
				lib.file.mkdirsSync outputUrl.directory, 0o0755 # TODO: We only need to do this once per directory.
				lib.fs.writeFileSync outputUrl.path, file.content
		
		# If there were any errors, log them, and clean out the build folder.
		errorMessage = inputDirectory.consolidateErrors()
		
		if errorMessage.length > 0
			console.error errorMessage if options.shouldLogErrors
			@cleanBuildFolder()
		
		# Call the callback.
		options.callback?()
	
	# Cleans out the build folder.
	cleanBuildFolder: ->
		# Since we're going to be deleting a folder, we do a little bit of sanity checking to help
		# prevent catastrophic occurrences.
		lib.wrench.rmdirSyncRecursive @outputPath, true if @outputPath.indexOf(@projectPath) is 0

# We only expose the run function.
exports.run = (options) ->
	# The command needs to be run inside of a fiber.
	(lib.fibers ->
		(new BuildCommand mode: options.mode).run options
	).run()
