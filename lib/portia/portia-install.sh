#!/bin/bash

# === Core Install Script for Portia ========================================

# --- add portia's bin and lib dirs to the path ---
export PATH=$BIN_ROOT/bin:$LIB_ROOT:$PATH

# --- import functions ---
source $LIB_ROOT/misc-functions.sh

# === Functions for Install Phase ===========================================

# --- fetch the binary tarballs ---
# fetches the binary tarballs if defined in BINFILES
# Initial working directory: WORK_DIR
bin_fetch() {
	# --- Add the default filename if BINFILES is unset ---
	if [ -z ${BINFILES+unset} ]; then BINFILES=$PVR.tgz; fi

	# --- break out if still no BINFILES ---
	if [ -z $BINFILES ]; then return 0; fi

	# --- fetch each distfile ---
	local _BINFILE
	for _BINFILE in $BINFILES; do

		local _SOURCE

		# --- figure out whether _BINFILE is a URI ---
		if [[ $_BINFILE =~ // ]]; then
			_SOURCE=$_BINFILE
		else
			_SOURCE=$DISTFILES_URI/$_BINFILE
		fi

		# --- fetch the source file ---
		vecho 1 "      fetching $_BINFILE"
		vecho 2 "         from $_SOURCE"
		vecho 2 "         to $WORK_DIR"
		acquire --noclobber -q $_SOURCE $WORK_DIR

		# --- die on error ---
		if [ $? -gt 0 ]; then
			vecho -1
			vecho -1 "Unable to download $_SOURCE"
			vecho 0 "aborting install"
			exit 1
		fi
	done
}

# --- unpack the binary tarballs ---
# This function is used to unpack all the binaries in WORK_DIR to STAGE_DIR.
# Initial working directory: STAGE_DIR
bin_unpack() {
	# --- localize variables ---
	local _FILE

	# --- unpack each binary tarball ---
	vecho 2 "         in" $( pwd )
	for _FILE in `find $WORK_DIR -maxdepth 1 -type f`; do
		#! TODO: implement unpack
		#unpack $_FILE
		vecho 1 "      unpacking $_FILE"
		tar xzf $_FILE
	done
}

# --- prepare binary files ---
# All preparation of the installed code should be done here.
# Initial working directory: STAGE_DIR
#bin_prepare() { return 0; }

# --- pre-install live filesystem modification script ---
# All modifications required on the live-filesystem before the
# package is merged should be placed here. Also commentary for the user  
# should be listed here as it will be displayed last.
#bin_preinstall() { return 0; }

# --- generate manifests ---
bin_manifest() {
	# --- make sure that INSTALL_ROOT exists ---	
	mkdir_safe $INSTALL_ROOT 'INSTALL_ROOT'

	# --- symlink INSTALL_ROOT to make commands cleaner ---
	#! commenting this out as it cause some problems and had no functional benefit
	#ln -s $INSTALL_ROOT live

	# --- generate the live and stage manifests ---
	vecho 2 "         in" $( pwd )
	vecho 1 "      generating stage.mf"
	manifest generate -qrTb $STAGE_DIR -O stage.mf
	vecho 1 "      generating live.mf"
	manifest generate -qTb $INSTALL_ROOT @stage.mf -O live.mf

	# --- get the current manifest ---
	vecho 1 "      fetching current.mf"
	if [ -e $DB_DIR/current.mf ]; then
		cp $DB_DIR/current.mf current.mf
	else
		# --- use empty manifest if no current ---
		touch current.mf
	fi
}

# --- installation script ---
bin_install() {
	# --- make sure things are in order before doing anyting ---
	mkdir_safe $INSTALL_ROOT 'INSTALL_ROOT'
	mkdir_safe $DB_DIR 'DB_DIR'

	# -- copy changed files from live to stage ---
	vecho 1 "      saving changed files"
	for _FILE in `manifest diff --changed -F fl current.mf live.mf`; do
		if [ -e $STAGE_DIR/$_FILE ]; then
			vecho 2 "         file '$_FILE' changed"
			mv $STAGE_DIR/$_FILE $STAGE_DIR/$_FILE.new
			cp $INSTALL_ROOT/$_FILE $STAGE_DIR/$_FILE
		fi
	done

	# --- remove deleted files from live ---
	vecho 1 "      removing deleted files"
	for _FILE in `manifest diff -oF fl current.mf stage.mf`; do
		vecho 2 "         deleting '$_FILE'"
		rm -f $INSTALL_ROOT/$_FILE
	done

	# --- remove empty directories from live ---
	vecho 1 "      removing empty directories"
	for _DIR in `manifest list -F d current.mf`; do
		if [ -d $_DIR ] && [ -n "$( ls -A $_DIR )" ]; then
			vecho 2 "         deleting '$_DIR/'"
			rmdir $_DIR
		fi
	done
	
	# --- install files ---
	vecho 1 "      installing files"
	vecho 2 "         to $INSTALL_ROOT"
	rsync -a $STAGE_DIR/ $INSTALL_ROOT/
	
	# --- copy stage manifest to DB_DIR ---
	vecho 1 "      saving new manifest"
	vecho 2 "         in $DB_DIR"
	cp stage.mf $DB_DIR/$PVR.mf
	ln -f $DB_DIR/$PVR.mf $DB_DIR/current.mf
}

# --- post-install cleanup ---
# Initial working directory: WORK_ROOT
bin_cleanup() {
	# -- this is redundant, but here for safety ---
	cd $WORK_ROOT

	if [ -d $CP ]; then
		vecho 1 "      removing temporary directory $WORK_ROOT/$CP"
		rm -rf $CP
	fi
}

# --- post-install live filesystem modification script ---
# All modifications required on the live-filesystem after the
# package is merged should be placed here. Also commentary for the user  
# should be listed here as it will be displayed last.
#bin_postinstall() { return 0; }

# --- other pkg_ functions in portage ---
#bin_prerm()     { return 0; }
#bin_postrm()    { return 0; }
#bin_config()    { return 0; }
#bin_pretend()   { return 0; }
#bin_nofetch()   { return 0; }
#bin_setup()     { return 0; }

# === Master Install Function ===============================================

# --- install phase ---
portia_install() {
	vecho 0 "Installing $C/$PVR"

   # --- make sure we have a clean work root ---
	cd_empty "$PWORK_DIR" PWORK_DIR

	# --- fetch the binaries ---
	mkdir -p "$WORK_DIR"; cd "$WORK_DIR"
	vrun 0 "   fetching binaries" bin_fetch

	# --- unpack the binaries --- 
	mkdir -p "$STAGE_DIR"; cd "$STAGE_DIR"
	vrun 0 "   unpacking binaries" bin_unpack

	# --- prepare the binaries --- 
	cd "$STAGE_DIR"; vrun 0 "   preparing binaries" bin_prepare

	# --- installation scripts ---
	cd "$STAGE_DIR"; vrun 0 "   running pre-installation script" bin_preinstall
	cd "$PWORK_DIR"; vrun 0 "   generating manifests" bin_manifest
	cd "$PWORK_DIR"; vrun 0 "   running installation script" bin_install
	cd "$PWORK_DIR"; vrun 0 "   running post-installaion script" bin_postinstall
	cd "$WORK_ROOT"; vrun 0 "   cleaning up" bin_cleanup

	vecho 0 "$PVR installed"
}
