# Squire #

Squire is a set of flexible front-end build tools for static content. It's equally usable for static websites, blogs, or single-page ajax-based web applications. It provides:

* File translation (i.e., CoffeeScript to JavaScript)
* File concatenation and generic dependency management
* A live preview server for easy, rapid development
* A generic plugin system to support all types of content
* A flexible configuration system


## Getting started ##

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

At this point you can begin editing your content. The changes will automatically be reflected every time you refresh the page. When you're ready to deploy, just run `squire build`. Your output will be in the build directory by default.


## Overview ##

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

The app directory forms the core of your project. When your project is built, any files in app/content will be placed into the build directory, getting processed by a plugin if a matching one is found. There is always a one-to-one correspondence of files in app/content to files in build.

Files that are in app but not in app/content do not get placed into build directly, but are made available in other ways. Plugins have access to the contents of the app directory via the [app tree](#the-app-tree), and [concat files](#concat-files) can be comprised of those contents as well.

### config ###

This directory contains configuration files that are written in [CSON](https://github.com/bevry/cson). You will typically have at least the file "squire.cson", which is used to configure Squire itself. You can also add plugin-specific configuration files by giving them the same name as the plugin. For example, the file "coffeescript.cson" would correspond to the coffeescript plugin.

See [Configuration Files](#configuration-files) for details on the contents of these files.

### plugins ###

This directory is optional. If you need to define any custom plugins, just place them in here and they will be available to use.

### build ###

This is where your compiled files get placed. It is recommended to add this directory to .gitignore. You don't need to create this directory yourself -- it will be created automatically whenever the project is built.


## Plugins ##

Each plugin defines one or more input file extensions and a single output extension. For example, the CoffeeScript plugin supports the "coffee" input extension and the "js" output extension. This means that any .coffee file in your app/content directory will get piped through the CoffeeScript plugin and then placed into the same relative location in the build directory with a .js extension. Any file that doesn't get matched to a plugin will get copied over untouched.

Note that for a plugin to be available you need to explicitly include it in [squire.config](#configuration-files) -- even for the built-in plugins.

Typically you don't need to worry too much about how plugins work beyond this unless you're writing your own plugin. See [this document](https://github.com/jlong64/squire/wiki/Creating-a-Squire-plugin) for details on how to do that.

Squire provides four built-in plugins: coffeescript, jade, stylus, and markdown. See [this page](https://github.com/jlong64/squire/wiki/Built-in-plugins) for details on how to use each of them.


## Index files ##

Index files files are any files inside app/content that have a base name of "index". They are given special treatment in that they will always compile to an HTML file regardless of the associated plugin's typical output extension.

Plugins that don't typically compile to HTML will often have special-case index file behavior to generate HTML rather than the typical output. For example, the CoffeeScript plugin will take an index.coffee file and gather a set of local variables from it. It will then proxy to a templating plugin, passing in the local variables to the associated template. This is very convenient for specifying template metadata or pre-processing the app tree before it hits the template.

See the documentation for each plugin for details on how they handle index files.


## Concat files ##

Concat files are one of the most powerful and useful features of Squire. They allow you to separate your code into multiple files during development, but compile them into a single file during the build process. They give you a great deal of flexibility in how this is done.

Concat files can only live inside the app/content directory. To specify that a file is a concat file, you prefix the extension with ".concat". For example, you would rename "app.js" to "app.concat.js". The ".concat" will be stripped out during the build process.

Inside the file you simply provide a list of files and/or directories, relative to the app directory, that will be included into the final file. Files are separated by newlines (empty lines and comment lines prefixed with # are okay), and the files will be compiled in the order they are listed in the concat file.

There is no limitation on mixing types in a concat file -- Squire is smart enough to pipe everything through the correct plugin before combining the final result. For this reason, the file extension of a concat file should always be the desired output extension. So even if your concat file contains only CoffeeScript files, you should call it "app.concat.js", not "app.concat.coffee".

Here is a simple example of a concat file.

```
# This file includes all of our JavaScript.
scripts/lib/jquery.js
scripts/lib/underscore.js
scripts/setup.coffee
scripts/script_a.coffee
scripts/script_b.coffee
scripts/script_c.coffee
scripts/init.coffee
```

It's a bit annoying to list out every file by hand though. Let's try this instead.

```
# This file includes all of our JavaScript.
scripts
```

This will recursively include all of the files inside app/scripts. Now whenever you add more files, they'll be automatically included without any extra effort on your part. However, there is no guaranteed order that the files will be included in. Squire provides a few ways to get around this problem. Here's one way.

```
# This file includes all of our JavaScript.
scripts/lib
scripts/setup.coffee
scripts
scripts/init.coffee
```

This will guarantee that all of the files inside the scripts directory will be included as before, but now everything in lib is guaranteed to be included first, followed immediately by setup, with init coming last. The order of the files inside lib is not guaranteed, but in this case that's okay.

Although script_a, script_b and script_c are guaranteed to be included after setup and before init, they are not guaranteed any order amongst themselves. But let's say script_b actually depends on script_a. We could type out the two files explicitly in the concat file, but as the project gets larger that's going to become unwieldy. Instead we can specify dependencies inside the files themselves, similar to how files are included or required in other programming languages. This is done with a specially-formatted comment near the top of the file.

__scripts/script_a.coffee__
```
class MyClassA
	# ...
```

__scripts/script_b.coffee__
```
#~ scripts/script_a.coffee

class MyClassB extends MyClassA
	# ...
```

Now script_b is guaranteed to be included after script_a.

The ~ character specifies that the comment is a dependency statement. There are several formats of accepted dependency statements to support dependency management across as many languages as possible. The supported formats are `#~ path/to/file`, `##~ path/to/file`, `//~ path/to/file`, and `/*~ path/to/file */`.

The file path can either be relative to the app directory or to the file itself by using the dot character. The path in the above example could have been written as either "./script_a.coffee" or "scripts/script_a.coffee".

Dependency statements are allowed to come after comments, but Squire will stop searching for statements once it encounters a non-comment or non-empty line.


## The app tree ##

During the build process, Squire will scan all of the files and directories in your app directory and generate the app tree. The app tree is a representation of all the content within the app directory, and it gets passed along to each plugin. Plugins can then pass the data on to you when it makes sense to do so (typically in templating language plugins).

The built-in Jade plugin, for example, will pass along the app tree as a local variable to your templates. You might use this if you are, say, creating an image gallery -- in your Jade template you can iterate over all the images in a particular directory and render them to the page.

See the documentation for each plugin for details on how they make use of the app tree.

The tree is made up of SquireDirectories and SquireFiles, which are documented below. The app tree itself is a SquireDirectory.

### SquireDirectory ###

<table>
	<tr>
		<td><strong>Property</strong></td>
		<td><strong>Type</strong></td>
		<td><strong>Description</strong></td>
	</tr>
	<tr>
		<td>name</td>
		<td>String</td>
		<td>The name of the directory.</td>
	</tr>
	<tr>
		<td>path</td>
		<td>String</td>
		<td>The path to the directory relative to the `app` directory.</td>
	</tr>
	<tr>
		<td>files</td>
		<td>Object</td>
		<td>An object with a key-value pair for each file in the directory. The keys are the names of the files, and the values are instances of SquireFile.</td>
	</tr>
	<tr>
		<td>directories</td>
		<td>Object</td>
		<td>An object with a key-value pair for each subdirectory in the directory. The keys are the names of the directories, and the values are instances of SquireDirectory.</td>
	</tr>
	<tr>
		<td>getPath</td>
		<td>Function</td>
		<td>
			A convenience function for getting a file or directory at the given path. i.e.:
			
			<code>logoFile = app.getPath "content/images/logo.png"</code>
		</td>
	</tr>
	<tr>
		<td>walk</td>
		<td>Function</td>
		<td>
			A function that will recursively iterate through all of the directory's subdirectories, calling a callback for each one. i.e.:
			
			<code>app.walk (directory) -> # Do something with each directory.</code>
		</td>
	</tr>
</table>

### SquireFile ###

<table>
	<tr>
		<td><strong>Property</strong></td>
		<td><strong>Type</strong></td>
		<td><strong>Description</strong></td>
	</tr>
	<tr>
		<td>name</td>
		<td>String</td>
		<td>The name of the file.</td>
	</tr>
	<tr>
		<td>path</td>
		<td>String</td>
		<td>The path to the file relative to the `app` directory.</td>
	</tr>
	<tr>
		<td>content</td>
		<td>String</td>
		<td>The contents of the file before being processed by its plugin.</td>
	</tr>
	<tr>
		<td>processedContent</td>
		<td>String</td>
		<td>The contents of the file after being processed by its plugin.</td>
	</tr>
</table>


## Configuration files ##

Squire supports configuration at the global level and the plugin level. All configuration files are written in [CSON](https://github.com/bevry/cson) and live in the config directory. The file "squire.cson" contains configuration for the entire build process, and any other files are specifically for plugins with the same name. "jade.cson" will correspond to the jade plugin, etc.

All config values should be placed into one of three namespaces: global, preview, or build. Global values are the base config values, while preview and build values will add to and override global values only in their corresponding environments. Here's what a squire.config file might look like.

```
global:
	appDirectory: "src"
	plugins: ["coffeescript", "jade", "stylus", "markdown"]
preview:
	minify: false
build:
	minify: true
```

Look at the documentation for each plugin to see the config values it supports. Here's what the Squire config file supports.

<table>
	<tr>
		<td><strong>Key</strong></td>
		<td><strong>Default</strong></td>
		<td><strong>Description</strong></td>
	</tr>
	<tr>
		<td>plugins</td>
		<td>[]</td>
		<td>The list of plugins that you want to use in your project. You'll almost always want to define this value, because no plugins are included by default.</td>
	</tr>
	<tr>
		<td>appDirectory</td>
		<td>"app"</td>
		<td>The name of the directory that contains all of the app files.</td>
	</tr>
	<tr>
		<td>inputDirectory</td>
		<td>"content"</td>
		<td>The name of the directory inside the app directory from which files are compiled into the build directory.</td>
	</tr>
	<tr>
		<td>outputDirectory</td>
		<td>"build"</td>
		<td>The name of the directory that the compiled files get placed into.</td>
	</tr>
	<tr>
		<td>ignoreHiddenFiles</td>
		<td>true</td>
		<td>Hidden files (files prefixed with a dot) will be ignored during the build process when this is true. This is helpful for preventing those pesky .DS_Store files from causing trouble.</td>
	</tr>
	<tr>
		<td>minify</td>
		<td>false during preview, true during build</td>
		<td>This isn't used by Squire itself, but some plugins use it to specify whether their output is minified or not.</td>
	</tr>
</table>


## License ##

TODO


## Thanks ##

TODO
