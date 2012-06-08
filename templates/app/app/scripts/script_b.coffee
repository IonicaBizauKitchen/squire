##
## scripts/script_b.coffee
## 
## Declares a class that inherits from a class declared in another file. We declare the dependency
## here to make sure things get included in the correct order.
##
#~ ./script_a.coffee

class CoolApp.MyClassB extends CoolApp.MyClassA
	doSomething: ->
		super
		console.log "Doing more stuff!"
