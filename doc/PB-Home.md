# Portia for Package Builders

## Install and Configure Portia

_link to installation and config - same docs as for End Users and SysAdmin_



## Create your Package

### Package Basics

Portia package files (a.k.a. pbuild files) are Bash libraries, pure and simple.

You set a bunch of variables to define your package and create functions to control each specific operation of the build and install cycles.  In many cases, you will be able to use default values for bot variables and functions.

### Common Practices and Rules of the Road

There are a number of rules and guidelines to follow when creating a pbuild file.

- **Define your variables at the beginning of the file**.  There is no functional requirement for things to be this way.  It's a matter of readability and consistency.  You'll make things easy on yourself by starting with the template provided in this documentation.
- **Don't include any executable statements outside of functions**.  Portia sources the pbuild file when loading it.  Placing a command outside of a function causes that command to be run when that library is loaded.  We (the developers of Portia) make no guarantee of when, where or how that happens and it may vary depending on the version of Portia you're running.
- **Use `exit` with caution**. i.e.
	- **Never place an `exit` outside a function**.  Portia will not be able to load the pbuild file if you do.
	- **Placing an `exit` in a function will abort all processing** for the given phase.  It's OK of that's what you want to do, but in most cases a `return` is more appropriate.
- **Don't source other pbuild scripts in your pbuild** unless you really know what you're doing.  There are legitimate reasons for breaking pbuilds into separate files, but there are caveats you must fully understand to avoid unexpected results.  More on this later.

## Variables

Portia used Bash-style variables for package configuration.  To see the current values of these variables, run `portia dump [PACKAGE|PBUILD-FILE]`.  Remember that command.  You'll be using it a lot.

For a full list and description of available variables, see the [Variables](Variables.md) page.

## The Template, Annotated

... working ...
