##
## scripts/setup.coffee
## 
## Sets up our global object.
##

window.CoolApp =
	init: ->
		a = new CoolApp.MyClassA
		b = new CoolApp.MyClassB
		c = new CoolApp.MyClassC
		
		a.doSomething()
		b.doSomething()
		c.doSomething()
