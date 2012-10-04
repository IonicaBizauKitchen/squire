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
		@message      = "\n#{message}"
		@fancyMessage = "\n" + lib.colors.red "\u2718 #{message}"
		
		if details?
			details        = "\n#{details}"
			details        = "\nIn #{path}:\n#{details}" if path?
			details        = details.replace /\n/g, "\n    "
			@message      += "\n#{details}"
			@fancyMessage += "\n#{details}"
		else if path?
			@message      += "\n\n    In #{path}"
			@fancyMessage += "\n\n    In #{path}"
		
		@message      += "\n"
		@fancyMessage += "\n"
	
	log: (fancy = true) ->
		console.error if fancy then @fancyMessage else @message
	
	toString: -> @message

# Expose class.
exports.Error = Error
