##
## main.coffee
## 
## The entry point into our library when including via require. It just provides access to the
## various contents of the package.
##

exports.Squire    = require("./core/squire").Squire
exports.Plugin    = require("./core/plugin").Plugin
exports.Directory = require("./core/directory").Directory
exports.File      = require("./core/file").File
exports.Url       = require("./core/url").Url
exports.Error     = require("./core/error").Error
