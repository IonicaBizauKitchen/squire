##
## classes/squire.coffee
## 
## The entry point into our library when including via require. It just provides access to the
## various contents of the package.
##

exports.Squire          = require("./classes/squire").Squire
exports.SquirePlugin    = require("./classes/squire_plugin").SquirePlugin
exports.SquireDirectory = require("./classes/squire_directory").SquireDirectory
exports.SquireFile      = require("./classes/squire_file").SquireFile
exports.UrlInfo         = require("./classes/url_info").UrlInfo
