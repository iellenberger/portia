# portia/.release/

This directory contains files, tools and uilitiies use for the development and release of Portia.

These files should be excluded from any packaged releases.

---

### mktarball.portia

	usage: mktarball.portia [RELEASE]

Generates a tarball of Portia suitable for upload as a source-release to places like [GitHub](https://github.com/iellenberger/portia/releases).

The tarball is generated using the parent directory as the root.
If RELEASE is not given, it is populated via `$ROOTDIR/portia --version`

See the contents of the script for details.