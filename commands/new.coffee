##
## commands/new.coffee
## 
## This contains the implementation of the new command.
##

lib =
	squire: require "../main"
	fs:     require "fs"
	path:   require "path"
	wrench: require "wrench"
	exec:   require("child_process").exec
	colors: require "colors"

class NewCommand extends lib.squire.Squire
	# The entry point to the command.
	run: (options) ->
		templatePath         = "#{@squirePath}/templates"
		selectedTemplatePath = "#{templatePath}/#{options.template}"
		outputPath           = lib.path.join @projectPath, options.path
		
		# Make sure that we received a valid template.
		unless lib.fs.existsSync selectedTemplatePath
			templates = (path for path in lib.fs.readdirSync(templatePath) when path[0] isnt ".").join ", "
			@logError "Template #{options.template} does not exist. Available templates are #{templates}."
			return
		
		# Make sure that the output path exists and is not empty.
		if lib.fs.existsSync outputPath
			if lib.fs.readdirSync(outputPath).length > 0
				@logError "Path #{outputPath} is not empty. Empty the contents of the directory or choose a new path."
				return
		else
			lib.wrench.mkdirSyncRecursive outputPath, 0o0755
		
		# Copy the template over.
		console.log "\nInitializing a new Squire project at #{outputPath} using #{lib.colors.bold(options.template)} template...\n"
		lib.exec "cp -r #{selectedTemplatePath}/* #{outputPath}"

# We only expose the run function.
exports.run = (options) -> (new NewCommand).run options
