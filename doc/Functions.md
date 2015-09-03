# Portia Functions

Portia uses Bash functions to execute each stage of the build and installation process.
In your .pbuild file, you can override any of these functions to provide the specific functionality your package needs.

All functions are stored as Bash libraries in LIB_ROOT.
Feel free to browse the libraries to fully understand how each function operates.

## The Processing Flow

### The Build Phase

* **Fetch** - download source archive(s)
* **Unpack** - unpack source archive(s)
* **Prepare** - apply patches 'n stuff
* **Configure** - configure the source code
* **Compile** - compile the source code
* **Test** - run post-compilation tests
* **Install** - install to staging location
* **Package** - package up the files for distribution

### The Install Phase

* **Fetch** - download binary archive(s)
* **Unpack** - unpack source archive(s)
* **Prepare** - template rendering and more!
* **Preinstall** - live filesystem changes before installation
* **Manifest** - manifest all new stuff before putting it in place
* **Install** - install stuff to its final location
* **Postinstall** - live filesystem changes before installation

## Build Functions

##### `src_fetch` - download source archive(s)

> **Default Action**: Download SRCFILES to DOWNLOAD\_DIR<br>
> **Initial Working Directory**: DOWNLOAD\_DIR
> 
> If you have defined SRCFILES in your pbuild, `src_fetch` downloads these files and places them in DOWNLOAD\_DIR.
> 
> SRCFILES can be any combination of space separated filenames or URIs.
> They will be downloaded in the sequence they are given.
> 
> At present, only single-file archives are supported - tarballs, zipfiles, etc - but you may specify any number of them.
> If you want to checkout a Git repository or do other specialized processing, you will need to override this with your own function.

##### `src_unpack` - unpack source archive(s)

> **Default Action**: Unpack tarballs in DOWNLOAD\_DIR to WORK\_DIR<br>
> **Initial Working Directory**: WORK\_DIR
> 
> `src_unpack` infs all files at the top level of DOWNLOAD\_DIR and unpacks them in WORK\_DIR.
> At present, the default functionality only supports tar-gzip archives.
> 
> It is considered best practice to build your archives with a unique top level directory.
> If your source archives are not built this way and you have more than one source archive,
> you risk having the files of one archive overwriting the files of another.
> If this is the case, you should override this function with your own.

##### `src_prepare` - apply patches 'n stuff

> **Default Action**: None<br>
> **Initial Working Directory**: WORK\_DIR
>
> Use this function for operations that need to take place before the source is configured, such as applying patches.

##### `src_configure` - configure the source code

> **Default Action**: None<br>
> **Initial Working Directory**: WORK\_DIR
>
> Use this function to perform source configuration actions like `make configure` or `./configure`.

##### `src_compile` - compile the source code

> **Default Action**: None<br>
> **Initial Working Directory**: WORK\_DIR
>
> Perform the compilation steps here.
> Example: `make clean; make all`

##### `src_test` - run post-compilation tests

> **Default Action**: None<br>
> **Initial Working Directory**: WORK\_DIR
>
> If your source has unit tests or other post-compilation tests, run them here.
> Example: `make check` or `make test`

##### `src_install` - install to staging location

> **Default Action**: None<br>
> **Initial Working Directory**: WORK\_DIR
>
> In this step, you will copy all files required for the binary installation to STAGE\_DIR.
> Exmaple: `make install`
> 
> Make sure you think about the layout of the files and directories in STAGE\_DIR, 'cause if you make a mess of it, you're going to have to sort it all out in the installation phase scripts.
> 
> At the end of this step, you objective is to have STAGE\_DIR be a verbatum copy of what you want in the installation package. 

##### `src_pack` - package up the files for distribution

> **Default Action**: Create a tarball of STAGE_DIR<br>
> **Initial Working Directory**: STAGE\_DIR
>
> This, quite simply, creates a tarball of $STAGE\_DIR/* an places it in $DISTFILES\_DIR/$PVR.tgz
> 
> The resulting tarball combined with the .pbuild file are the binary distribution of the package.

##### `src_post` - user-defined post-build hook
> **Default Action**: None<br>
> **Initial Working Directory**: STAGE\_DIR
>
> Here if you need it.  A good time to grab a copy of the built tarball if you have a need for it.

##### `src_cleanup` - temporary directory cleanup
> **Default Action**: Delete temporary directories<br>
> **Initial Working Directory**: WORK\_ROOT
>
> Deletes WORK\_ROOT.

## Install Functions

##### `bin_fetch` - download binary archive(s)

> **Default Action**: Download BINFILES to DOWNLOAD\_DIR<br>
> **Initial Working Directory**: DOWNLOAD\_DIR
>
> This function works almost identically to `src_fetch`,
> except that it uses the variable BINFILES as its file list.

##### `bin_unpack` - unpack source archive(s)

> **Default Action**: Unpack tarballs in DOWNLOAD\_DIR to STAGE\_DIR <br>
> **Initial Working Directory**: STAGE\_DIR
>
> This function works identically to `src_unpack`.

##### `bin_prepare` - template rendering and more!

> **Default Action**: None<br>
> **Initial Working Directory**: STAGE\_DIR
>
> Use this function to modify the files in STAGE\_DIR to become a verbatum copy of what you want installed.

##### `bin_preinstall` - live filesystem changes before installation

> **Default Action**: None<br>
> **Initial Working Directory**: STAGE\_DIR
>
> Any additional work that is required before installing the files for the package should be done here.
> Common uses include stopping services, converting databases, snapshotting data, etc.

##### `bin_manifest` - manifest all new stuff before putting it in place

> **Default Action**: Generates installation manifests<br>
> **Initial Working Directory**: PWORK\_DIR
> 
> This is a highly specialized function that Portia uses to generate manifests for package installation.
> In general, you will not want to make any changes here.

##### `bin_install` - install stuff to its final location

> **Default Action**: Copy files from STAGE\_DIR to PWORK\_DIR<br>
> **Initial Working Directory**: PWORK\_DIR
> 
> This function intelligently copies the files in STAGE\_DIR to PWORK\_DIR, saving off any files that may have been modified by the user and deleting files that have been removed from the package (upgrade scenario).
> 
>  Along with `bin_manifest`, this function should not be overridden.

##### `bin_postinstall` - live filesystem changes before installation

> **Default Action**: None<br>
> **Initial Working Directory**: PWORK\_DIR
>
> Any additional work that is required after installing the files for the package should be done here.
> Common uses include stopping services, initializing databases, restoring data, etc.

## Utility Functions


##### `mv_n SRC DEST`


##### `mkdir_safe DIR LABEL`


##### `cd_empty DIR LABEL`


##### `vecho VERBOSITY MESSAGE`


##### `vrun VERBOSITY MESSAGE FUNCTION`


##### `run_fn FUNCTION`



## Utility Commands

##### `manifest OPTIONS`

> Portia uses 'manifest' to create checksum manifests of the files it installs.
> It uses those manifests to:
>
> * log all files for the current installation
> * test for file changes between installations
> * determine whether it can safely replace existing files
> * delete files that have been removed from the package
>
> Run `manifest -?` for usage or `manifest --man` for the full manual page.

##### `acquire OPTIONS`

> This is a highly simplifed version of 'curl`.
>
> 'curl' is not a standard part of most *nix distributions and we didn't want
> to require that SysAdmins install it in order to run Portia, so we created
> our own utility to perform curl-ish actions.
>
> Run `acquire -?` for usage or `acquire --man` for the full manual page.

