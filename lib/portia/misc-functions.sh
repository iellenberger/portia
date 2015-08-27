#!/bin/bash

# --- move without overwrite ---
#
# usage: mv_n DIR
#
# mv_n() emulates the BSD command, "mv -n" which is not available on the
# GNU/FSF distributions.  The mv(1) manpage describes the -n option as
# follows:
#
#    -n  Do not overwrite an existing file
#
# This option was added to the GNU version in 2009 and is now generally
# available on most systems.
# ref: http://lingrok.org/xref/coreutils/NEWS#1999
#
mv_n() {
	SRC=$1; DEST=$2
	# --- don't overwrite DEST ---
	if [ -e $DEST ]; then return 0; fi
	vecho 2 "      moving $SRC -> $DEST"
	mv $SRC $DEST
}

# --- mkdir replacement ---
#
# usage: mkdir_safe DIR [LABEL]
#
# mkdir_safe() attempts to create the directory DIR and errors out if it
# fails or if DIR exists and is not writeble by the current user.
#
# LABEL is an optional string used to describe the directory for error messages
# such as the following:
#
#    "$LABEL less then 10 characters below the root of the filesystem."
#
# If not set, LABEL defaults to the word 'directory'.
#
mkdir_safe() {
	local _DIR=$1; local _LABEL=$2

	# --- make sure we have at least a fake label name ---
	if [ -z $_LABEL ]; then _LABEL='directory'; fi

	# --- create the dir and its parents ---
	if [ ! -e $_DIR ]; then
		vecho 1 "      creating $_LABEL '$_DIR'"
		mkdir -p $_DIR
		# --- unable to create dir ---
		if [ ! -d $_DIR ]; then
			vecho -1
			vecho -1 "Unable to create '$_DIR'"
			vecho 0 "Please ensure that that the parent directory exists"
			vecho 0 "   and is writable by $USER, or run the program as another user"
			exit 1
		fi

	# --- another file is in the way ---
	elif [ ! -d $_DIR ]; then
		vecho -1
		vecho -1 "'$_DIR' is not a directory"
		vecho 0 "Another file is in the way.  Please remove it"
		exit 1

	# --- directory not writable ---
	elif [ ! -w $_DIR ]; then
		vecho -1
		vecho -1 "'$_DIR' is not writable"
		vecho 0 "Change permissions so that it writable by $USER"
      vecho 0 "   or run the program as another user"
		exit 1
	fi
}

# --- a safer version of mkdir + cd + rm -r * ---
#
# usage: cd_empty DIR [LABEL]
#
# cd_empty() creates, changes to and deletes all existing files in DIR.
# For safety, it will exit with an error if the directory is less than 10
# characters from the root of the filesystem.  (This function should never be
# executed outside of var/portia or some similar, longer directory)
#
# LABEL is an optional string used to describe the directory for error messages
# such as the following:
#
#    "$LABEL less then 10 characters below the root of the filesystem."
#
# If not set, LABEL defaults to the word 'directory'.
#
cd_empty() {
	local _DIR=$1; local _LABEL=$2

	# --- create and cd to _DIR ---
	mkdir_safe $_DIR; cd $_DIR

	# --- get the symlink-expanded directory name ---
	_PWD=$(pwd -P)

	# --- PWD must be at least 10 characters long ---
	if [ ${#_PWD} -lt 10 ]; then

		# --- make sure we have at least a fake label name ---
		if [ -z $_LABEL ]; then $_LABEL='directory'; fi

		# --- spit out an error message ---
		echo "Unsafe operation: $_LABEL is less then 10 characters long"
		echo "   $_LABEL = '$_PWD', length ${#_PWD}"
		echo "Cowardly refusing to perform an rm -rf *"
		echo "   cd_empty() exiting"

		# --- exit with error code ---
		exit 1
	fi

	# --- if we got here, we should be safe ---
	vecho 2 "      emptying $_PWD/"
	rm -rf .[^.]* ..?* *
}

# --- echo based on verbosity level ---
#
# usage: vecho LEVEL MESSAGE
#
# vecho() will echo MESSAGE if the current verbosity level >= LEVEL
#
vecho() {
	local _VERBOSITY=$1; shift

	if [ $VERBOSITY -ge $_VERBOSITY ]; then
		echo "$*"
	fi
}

# --- run a function with a message ---
#
# usage: vrun LEVEL MESSAGE FUNCTION [PARAM(s)]
#
# if FUNCTION exists, vrun() will:
#    echo MESSAGE if the current verbosity level >= LEVEL
#    call FUNCTION wuth all given PARAM(s)
#
# MESSAGE must be in quotes and properly escaped if it contains whitespace
# or special characters
#
vrun() {
	local _VERBOSITY=$1; shift
	local _MESSAGE=$1;   shift
	local _FUNCTION=$1

	if [ "$( type -t $_FUNCTION )" == 'function' ]; then
		vecho $_VERBOSITY "$_MESSAGE"
		$*
	fi
}

# --- run a function if it exists or error out ---
#
# usage: run_fn FUNCTION [PARAM(s)]
#
# run_rn() will call FUNCTION wuth all given PARAM(s) if it exists,
# if FUNCTION is not defined, run_fn will print a failure message and exit
# with a 1.
#
run_fn() {
	local _FUNCTION=$1
	if [ "$( type -t $_FUNCTION )" == 'function' ]; then
		$* ||
			echo "execution failed in function $_FUNCTION" &&
			exit 1
	fi
}
