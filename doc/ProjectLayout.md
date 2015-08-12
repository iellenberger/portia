# Best Practices: Project Layout

### Think About It Early

A lot of developers don't think about is how to structure their software for deployment.  Early on in the development process this doesn't matter much, but as you start sharing your code and getting ready for release deployment can become a real challenge.

Developers often spend a lot of valuable time after-the-fact completely restructuring their project to conform to some arbitrary deployment structure.  A lot of effort can be saved by simply spending a few minutes early on thinking about what the end product is going to look like.

### There is a Standard

If you're at all familiar with *nix, you have already been exposed to the [Filesystem Hierarchy Standard](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard) (FHS).  Using this as a reference when initially structuring your own project will make plugging into almost any deployment framwork easy.

Portia, by design, strongly encourages the use of FHS structured deployments with a relocatable root.

### What's a Relocatable Root?

A relocatable root means that the root of your installation may not be in `/`.
Instead, it's defined by the installer and may be almost anywhere on the filesystem.

The benefits of a relocatable root include:

* **Multiple Environments**.  You can setup multiple installations of the same software on the same machine.  Most often you can change environments just by changing your path.
* **Isolated Environments**.  Everything is on one directory tree.  It's easy to find all the files for related applications: binaries, configs, logs, etc.  Makes it easy to backup as well.
* **Easy to Rebuild and Destroy**.  Need to delete it?  Just delete the whole directory.  Rebuild it?  Restore the whole tree from a backup or use Portia to reinstall.
* **Great Compatibility**.  You'll find that structuring your code and installations like this dovetails nicely into almost any development and deployment framework.

### So What Do I Need to Do?

If your an **installer** or **systems administrator**, read through the next section.
If you're a **package builder** read the next two sections so you can get context of what the sysadmins have to deal with.
If you're a **application developer**, you need lots of context so you're gonna have to read the whole doc.
Trust me on this one, it's a really worthwhile exercise.

For the all examples, let's presume that Portia is installed in `/opt/portia/` and you'll be wanting to install your application in `/opt/myenv/`

## For Installers and SysAdmins

In Portia, there are a three ways you can define the installation root directory:

1. **Do nothing** to have packages installed in `/usr/local/`.
2. **Set the INSTALL_ROOT** to define an alternate installation location.
3. **Create some symlink magic** and have Portia change its INSTALL_ROOT based on where you run it.

Details below.  Choose your poison.

### 1. Do Nothing

By default, Portia uses `/usr/local/` as it's INSTALL_ROOT.

If you don't want your app installed in there, read on.

### 2. Set INSTALL_ROOT

There are three ways you can set INSTALL_ROOT:

**A. Set the shell variable and import it on the command line** 

```
export INSTALL_ROOT=/opt/myenv
portia --import INSTALL_ROOT [...]
```

**B. Import it on the CLI without setting it in the shell**

```
portia --import INSTALL_ROOT=/opt/myenv [...]
```

**C. Set it in Portia's config file (preferred method)**

Edit `portia.conf` to include:

```
#!/bin/bash

INSTALL_ROOT=/opt/myenv
```

Portia uses the following path to find it's config file.

* `/etc/portia/portia.conf`
* {Portia's absolute root dir}`/etc/portia/portia.conf`
* {Portia's relative root dir}`/etc/portia/portia.conf`
* `~/.portia/portia.conf`

where the last encoutered variable wins.
(ex `~/.portia/portia.conf` overwrites values in `/etc/portia/portia.conf`)

(**Developers**, pay attention.  We'll be talking about this later)

### 3. Create Some SymLink Magic

Did you notice that whole, "absolute/relative root dir" thing a few lines back?
That's an important feature of Portia that shouldn't be overlooked.

Here's how it works.

With Portia's binary being `/opt/portia/bin/portia`, its relative root directory is `/opt/portia`.
Since there are no symlinks in this path, its absolute path is also `/opt/portia`.
That means this is the config file search path:

* `/etc/portia/portia.conf`
* `/opt/portia/etc/portia/portia.conf`
* `/opt/portia/etc/portia/portia.conf` (redundant, but harmless)
* `~/.portia/portia.conf`

Now here's the magic.
If you create a symlink to Portia's binary in `/opt/myapp/bin/` and run `/opt/myapp/bin/portia`, the search path changes:

* `/etc/portia/portia.conf`
* `/opt/portia/etc/portia/portia.conf`
* `/opt/myapp/etc/portia/portia.conf` (Ohhhh, ahhhh.  Magic!)
* `~/.portia/portia.conf`

This means you can control INSTALL_ROOT in `/opt/myapp/etc/portia/portia.conf`.

### Additional Note on PATHs for SysAdmins

If you are running Portia in a multi-environment context, you can change which copy (symlink, actually) of Portia will run in a given shell by simply rewiting the PATH variable.

## For Package Builders

As a package builder, there are three key things you need to pay attention to:

1. Do your work in the WORK\_DIR
2. Keep your STAGE\_DIR pristine
3. Avoid absolute paths

There are edge cases where these guidelines cannot be followed, but be very careful when doing otherwise.
It may make your package unusable for system administrators and installers.

### Do Your Work in the WORK\_DIR

During both the build and install phases, Portia unpacks downloaded source archives into the WORK\_DIR.
This is the place you should do all of your work.

### Keep Your STAGE\_DIR Pristine

The STAGE\_DIR is intended to be a snapshot of your deliverable.

In the build phase, Portia's default action is to create a tarball snapshot of STAGE\_DIR for upload to the binary repository.
You should only place files needed during the install phase in STAGE\_DIR.

In the install phase, Portia's default action is to copy STAGE\_DIR verbatum to INSTALL\_DIR.
You should structure STAGE\_DIR to be the same layout as the INSTALL\_DIR target, and all files should be in their final form.

### Avoid Absolute Paths

When writing .pbuild files, use relative paths wherever possible and [Portia path variables](Variables.md) everwhere else.
This will allow system administrators and installers to relocate your package to wherever the require.

Remember that there is no guarantee that files outside of Portia controlled directories will conform to your expectations.

## For Application Developers

As an application developer, it is triply important that you pay attention to standards like the [FHS](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard).
Well structured repositories and source structures makes it much easier for package builders, installers and system administrators alike.

Key things to follow:

* Structure your repositories so that non-developers can easily work with them.
* Break up your build process into the standard makefile-style sequence of operations: configure, clean, all (a.k.a. build), test, install.
* Make sure that your install operation is able to deliver build products to an arbitrary location.
* Make sure your build products can operate in an arbitrary install location.

That last one is so important, I'm giving it's own title ...

### Make Your Binaries are Relocatable

How do you do that?
Simple - don't hard code paths into your binaries.
I't kinda dickish to require that installers recompile your whole package if they want to move it to another location on the filesystem.

#### So how do I do that?

> Remember when I told you to pay attention back in the **For Installers and SysAdmins - Create Some SymLink Magic** section?
> You weren't paying attention, were you.
> If you haven't read that bit or don't remember it, go back and read it now.
> The paragraphs below show you how to implement it for your programs.

Your programs should always be able know where their *virtual root* is and should look under that directory for all its configuration files.
For example, if I install your application in `/opt/myenv/bin/your_program`, it should be intelligent enough to find its configuration files in `/opt/myenv/etc/your_program` and not immediately look in `/etc/your_program`.  Every language has some facility to accomodate this - you just have to use it.

Here are some examples of code to find the paths of the root directory:

##### Bash

```
# --- without resolving symlinks ---
APP_ROOT=$(cd $(dirname $0/..; pwd)
# --- resolving symlinks ---
NOSYM_ROOT=$(cd $(dirname $0/..); pwd -P)
```

##### Perl 5

```
use Cwd qw( abs_path );
use FindBin qw( $Bin $RealBin );

# --- without resolving symlinks ---
my $APP_ROOT = "$Bin/..";
# --- resolving symlinks ---
my $NOSYM_ROOT = abs_path("$RealBin/..");
```

I'll provide more examples in other languages when I bother to look them up.

## Reference

**The Filesystem Hierarchy Standard**

* [Official documentation](http://refspecs.linuxfoundation.org/fhs.shtml) - If RFCs are your usual bedtime reading, you'll love this
* [On Wikipedia](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard) - Covers the important bits, easy to read