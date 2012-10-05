##
## core/error.coffee
## 
## A class that encapsulates an error.
##

lib =
	colors: require "colors"

exports.Error = class Error
	# A shortcut for logging an error.
	@log: (options) -> (new exports.Error options).log options.fancy
	
	constructor: ({message, details, path}) ->
		@plainMessage = "\n#{message}"
		@fancyMessage = "\n" + lib.colors.red "\u2718 #{message}"
		
		if details?
			details        = "\n#{details}"
			details        = "\nIn #{path}:\n#{details}" if path?
			details        = details.replace /\n/g, "\n    "
			@plainMessage += "\n#{details}"
			@fancyMessage += "\n#{details}"
		else if path?
			@plainMessage += "\n\n    In #{path}"
			@fancyMessage += "\n\n    In #{path}"
		
		@plainMessage += "\n"
		@fancyMessage += "\n"
	
	log: (fancy = true) ->
		console.error if fancy then @fancyMessage else @plainMessage
	
	toString: -> @message

# Expose class.
exports.Error = Error
