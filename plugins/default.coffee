##
## plugins/default.coffee
## 
## The default plugin, which is used for extensions that are not handled by other plugins. It just
## copies files over directly without modifications.
##

lib =
	squire: require "../squire"
	exec:   require("child_process").exec

class exports.Plugin extends lib.squire.BasePlugin
	buildFile: (inputUrl, outputUrl, callback) ->
		lib.exec "cp #{inputUrl} #{outputUrl}", (error, stdout, stderr) ->
			throw error if error?
			callback()
