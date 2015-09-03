# Portia Variables

Portia sets and uses a number of variables for its operation, and passes these variables to the scripts performing the build ind installation process.

These variables may be set by using:

* Bash's `export`, prior to running Portia. (Other shells may use different commands)
* Portia's command line.
* Variables set in .pbuild files.

To see the current values for a given system, package or .pbuild file, run one of the following commands (replace ALL CAPS bits as appropriate):

```
portia dump
portia dump PACKAGE
portia dump PBUILD-FILE
```

Most variables have both short and long names.
Whenever possible, use the long names for readability.
The sort names are provided for cases where the long names are simply to cumbersome.

If you try to set both the short and long version of a variable, the long version will override the short version.

## Filesystem Locations

Portia does it's work in various locations on the filesystem.
The following is a tree'd representation of the variables that define these locations.

```
Short & Long Name          Default Value
-------------------------  --------------------------------
BR   BIN_ROOT              Parent of Portia's bin directory
       PORTIA_BIN          BIN_ROOT/bin/portia
LR     LIB_ROOT            BIN_ROOT/lib/portia
IR   INSTALL_ROOT          /usr/local

PR   PORTIA_ROOT           BIN_ROOT
PL     PORTIA_LIB          PORTIA_ROOT/var/lib/portia
DB       DB_ROOT           PORTIA_LIB/db
DBD        DB_DIR          DB_ROOT/CATEGORY/PACKAGE
DR       DISTFILES_ROOT    PORTIA_LIB/distfiles
DD         DISTFILES_DIR   DISTFILES_ROOT/CATEGORY/PACKAGE
EP     ETC_PATH            PORTIA_ROOT/etc/portia

TR     TMP_ROOT            PORTIA_ROOT/var/tmp
WR       WORK_ROOT         TMP_ROOT/portia
PW         PWORK_DIR       WORK_ROOT/CATEGORY/PACKAGE
DL           DOWNLOAD_DIR  PWORK_DIR/download
WD           WORK_DIR      PWORK_DIR/work
SD           STAGE_DIR     PWORK_DIR/stage

       PBUILD_DIR          Directory of .pbuild file
       PBUILD_FILE         .pbuild file name
```

Any change you make to these variables outside of a pbuild function will be inherited by the dependent variables unless you have already explicitly defined the dependant variable to be another value.

Example:
If you define `TMP_ROOT=/mytmp`, `WORK_ROOT` will have the value `/mytmp/portia` unless you have already defined `WORK_ROOT` to be something else.

##### `BIN_ROOT`, `BR`
> **Read-only, default:** Computed based on the location of the Portia binary
> 
> This is the directory Portia considers its root.
> All of Portia's binaries are self-contained under this directory.
> 
> This directory is one level above the Portia binary.
> If Portia's binary is `/opt/mystuff/bin/portia`, `BIN_ROOT` will be `/opt/mystuff`.

##### `PORTIA_BIN`
> **Read-only, default:** `BIN_ROOT/bin/portia`
> 
> The location of Portia's binary.

##### `LIB_ROOT`, `LR`
> **Default:** `BIN_ROOT/lib/portia`
> 
> The location of Portia's library directory.

##### `INSTALL_ROOT`, `IR`
> **Default:** `/usr/local`
> 
> The base directory under which Portia will install packages.

##### `PORTIA_ROOT`, `PR`
> **Default:** `BIN_ROOT`
> 
> The location under which Portia will do all its work.

##### `PORTIA_LIB`, `PL`
> **Default:** `PORTIA_ROOT/var/lib/portia`
> 
> The location Portia will keep its stateful files.

##### `DB_ROOT`, `DB`
> **Default:** `PORTIA_LIB/db`
> 
> The location Portia keeps its build products and descriptors.

##### `DB_DIR`, `DBD`
> **Default:** `DB_ROOT/CATEGORY/PACKAGE`
>
> The location build products for a specific package ar kept.

##### `DISTFILES_ROOT`, `DR`
> **Default:** `PORTIA_LIB/distfiles`
> 
> The local package repository cache.

##### `DISTFILES_DIR`, `DD`
> **Default:** `DISTFILES_ROOT/CATEGORY/PACKAGE`
> 
> The local package repository cache for a particular package.

##### `ETC_PATH`, `EP`
> **Default:** `PORTIA_ROOT/etc/portia`
> 
> Configuration files for this installation of Portia.

##### `TMP_ROOT`, `TR`
> **Default:** `PORTIA_ROOT/var/tmp`
> 
> Root directory for temporary files.

##### `WORK_ROOT`, `WR`
> **Default:** `TMP_ROOT/portia`
> 
> Root directory for Portia's work.

##### `PWORK_DIR`, `PW`
> **Default:** `WORK_ROOT/CATEGORY/PACKAGE`
> 
> Root directory for package-specific work.

##### `DOWNLOAD_DIR`, `DL`
> **Default:** `PWORK_DIR/download`
> 
> Temporary download location for `*_fetch()` operations.

##### `WORK_DIR`, `WD`
> **Default:** `PWORK_DIR/work`
> 
> Directory where builds and pre-installation work is performed.

##### `STAGE_DIR`, `SD`
> **Default:** `PWORK_DIR/stage`
> 
> The 'fake' install root used when packages are created or staged for installation.

##### `PBUILD_DIR`; `PBUILD_FILE`
> If you specified a .pbuild file on the command line,
> these are the location and filename of the file.

## Hardware and Operating System

##### `OS_NAME`
> **Read-only, default:** Computed
> 
> The name of the base operating system.
> 
> Supported values: `linux`, `darwin`

##### `OS_DIST`
> **Read-only, default:** Computed
> 
> The name of the operating system distribution.
> 
> Supported values: `macos` (pre 10.4), `os-x`, `centos`, `redhat`

##### `OS_VERSION`
> **Read-only, default:** Computed
> 
> The specific version of the operating system.
> 
> Ex. OS-X Yosemite (latest as of this writing) would have the value `10.10.5`

##### `HW_ARCH`
> **Read-only, default:** Computed
> 
> The architecture of the hardware.
> 
> Supported values: `i386`, `i686`, `amd64`, `x86_64`

##### `TAR`
> **default:** Computed
> 
> The full path to the `tar` binary.
> Searches the path for either `gnutar` ('cause OS-X's version of tar is gimped) or `tar`.

## Package, Version Revision and Category

These define the values used to uniquely identify a package.
For this documentaion we will use the package, "sys-apps/portia/portia-0.1.0-dev-unstable"

##### `PACKAGE`, `P`
> **Default:** Defined in package or .pbuild file
> 
> Example: `portia`

##### `VERSION`, `V`
> **Default:** Defined in package or .pbuild file 
> 
> Example: `0.1.0-dev`

##### `REVISION`, `R`
> **Default:** Defined in package or .pbuild file
> 
> Example: `unstable`

##### `CATEGORY`, `C`
> **Default:** Defined in package or .pbuild file
> 
> Example: `sys-apps`

##### `PV` (Package Version)
> **Default:** `P-V` 
> 
> Example: `portia-0.1.0-dev`

##### `PVR` (Package Version Release)
> **Default:** `P-VR`
> 
> Example: `portia-0.1.0-dev-unstable`

##### `VR` (Version Release)
> **Default:** `V-R`  
> 
> Example: `0.1.0-dev-unstable`

##### `CP` (Category Package)
> **Default:** `C/P`  
> 
> Example: `sys-apps/portia`

##### `CPV` (Category Package Version)
> **Default:** `CP/PV`   
> 
> Example: `sys-apps/portia/portia-0.1.0-dev`

##### `CPVR` (Category Package Version Release)
> **Default:** `CP/PVR`
> 
> Example: `sys-apps/portia/portia-0.1.0-dev-unstable`

## Repositories

The URIs where a package will be stored and/or fetched.  For this documentation we will use, "sys-apps/portia" with a local repository in, "/opt/myrepo"

##### `REPO_URI`, `RU`
> **Default:**
> 
> Example: `file:///opt/myrepo`

##### `PACKAGE_URI`, `PU`
> **Default:** `REPO_URI/packages/CATEGORY/PACKAGE`
> 
> Example: `file:///opt/myrepo/packages/sys-apps/portia`

##### `DISTFILES_URI`, `DU`
> **Default:** `REPO_URI/distfiles/CATEGORY/PACKAGE`
> 
> Example: `file:///opt/myrepo/distfiles/sys-apps/portia`