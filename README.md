# Squire #

Squire is a set of flexible front-end build tools for static content. It's equally usable for static websites, blogs, or single-page ajax-based web applications. It provides:

* File translation (i.e., CoffeeScript to JavaScript)
* File concatenation and generic dependency management
* A live preview server for easy, rapid development
* A generic plugin system to support all types of content
* A flexible configuration system


# Getting started #

Make sure [node.js](http://nodejs.org/) and [npm](http://npmjs.org/) are installed and use npm to install the package. The `-g` flag is necessary to make the `squire` command-line utility available.

```
sudo npm install -g squire
```

You can then initialize a new project.

```
squire new path/to/project
```

You may use the `-t` option to change the project template. *TODO: List the templates.*

Once that's done you're ready to start up a preview server.

```
cd path/to/project
squire preview
```

At this point you can begin editing your content. The changes will automatically be reflected every time you refresh the page. When you're ready to deploy, just run `squire build`. Your output will be in the `build` directory by default.


# Overview #

The core functionality of Squire is to take in a set of files and run them through plugins to process them in some way. To do this, it expects your project to be structured in a particular way. It should look something like this.

```
app/
	content/
config/
	squire.cson
plugins/
build/
```

### app and app/content ###

The `app` directory forms the core of your project. When your project is built, any files in `app/content` will be placed into the `build` directory, getting processed by a plugin if a matching one is found. There is always a one-to-one correspondence of files in `app/content` to files in `build`.

Files that are in `app` but not in `app/content` do not get placed into `build` directly, but are made available in other ways. Plugins have access to the contents of the `app` directory via the app tree *(TODO: Add link)*, and concat files *(TODO: Add link)* can be comprised of those contents as well.

### config ###

This directory contains configuration files that are written in CSON *(TODO: Add link)*. You will typically have at least the file `squire.cson`, which is used to configure Squire itself. You can also add plugin-specific configuration files by giving them the same name as the plugin. For example, the file `coffeescript.cson` would correspond to the coffeescript plugin.

See Configuration Files *(TODO: Add link)* for details on the contents of these files.

### plugins ###

This directory is optional. If you need to define any custom plugins, just place them in here and they will be available to use.

### build ###

This is where your compiled files get placed. It is recommended to add this directory to .gitignore.


# Plugins #

Each plugin defines one or more input file extensions and a single output extension. For example, the CoffeeScript plugin supports the "coffee" input extension and the "js" output extension. This means that any .coffee file in your `app/content` directory will get piped through the CoffeeScript plugin and then placed into the same relative location in the `build` directory with a .js extension. Any file that doesn't get matched to a plugin will get copied over untouched.

Typically you don't need to worry too much about how plugins work beyond this unless you're writing your own plugin. See this document *(TODO: Add link)* for details on how to do that.

Squire provides four built-in plugins: coffeescript, jade, stylus, and markdown *(TODO: Add links)*. See their documentation for details on how to use them.


# Index files #

Index files files are any files inside `app/content` that have a base name of "index". They are given special treatment in that they will always compile to an index.html file regardless of the associated plugin's typical output extension.

Plugins that don't typically compile to HTML will often have special-case index file behavior to generate HTML rather than the typical output. For example, the CoffeeScript plugin will take an index.coffee file and gather a set of local variables from it. It will then proxy to a templating plugin, passing in the local variables to the associated template. This is very convenient for specifying template metadata or pre-processing the app tree before it hits the template.

See the documentation for each plugin for details on how they handle index files.


# Concat files #

Concat files are one of the most powerful and useful features of Squire. They allow you to separate your code into multiple files during development, but compile them into a single file during the build process. They allow for a great deal of flexibility in how this is done.

TODO: Explain how to create concat files, etc.

### Dependency management ###

TODO


# The app tree #

During the build process, Squire will scan all of the files and directories in your `app` directory and generate the app tree. The app tree is a representation of all the content within the `app` directory, and it gets passed along to each plugin. Plugins can then pass the data on to you when it makes sense to do so (typically in templating language plugins).

The built-in Jade plugin, for example, will pass along the app tree as a local variable to your templates. You might use this if you are, say, creating an image gallery -- in your Jade template you can iterate over all the images in a particular directory and render them to the page.

The tree is made up of SquireDirectories and SquireFiles, which are documented below. The app tree itself is a SquireDirectory.

### SquireDirectory ###

* __name__: The name of the directory.
* __path__: The path to the directory relative to the `app` directory.
* __files__: An object with a key-value pair for each file in the directory. The keys are the names of the files, and the values are instances of SquireFile.
* __directories__: An object with a key-value pair for each subdirectory in the directory. The keys are the names of the directories, and the values are instances of SquireDirectory.
* __getPath__: A convenience function for getting a file or directory at the given path.
* __walk__: A function that will recursively iterate through all of this directory's subdirectories, calling a callback for each one.

TODO: Examples.

### SquireFile ###

* __name__: The name of the file.
* __url__: The URL that points to the file relative to the `app` directory.
* __content__: The contents of the file before being processed by its plugin.
* __output__: The contents of the file after being processed by its plugin.
* __plugin__: A reference to the plugin associated with this file.

TODO: Examples.


# Configuration files #

TODO

