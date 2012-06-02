##
## plugins/default.coffee
## 
## The default plugin, which is used for extensions that are not handled by other plugins. It just
## returns the input without processing it.
##

lib =
	squire: require "../squire"
	exec:   require("child_process").exec

class exports.Plugin extends lib.squire.SquirePlugin
	renderContent: (input, options, callback) ->
		callback input
