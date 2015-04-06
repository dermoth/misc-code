#!/bin/bash

# First check if we've been invoked trough a symlink and find the real path
scriptname="$(readlink -e "$0")"
# Then get the config directory
configdir="$(dirname "$scriptname")/colorize.d"

if [ ! -d "$configdir" ]
then
	echo "ERROR: \`$configdir' does not exists."
	exit 1
fi

print_help() {
	echo
	echo "Usage: colorize <config>"
	echo
	echo "  <config> is one of the files in $configdir/:"
	for f in "$configdir/"*
	do
		# Skip non-readable files and non-regular files
		[ -r "$f" -a -f "$f" ] || continue
		unset DESC
		. "$f"
		echo "    $(basename "$f"): ${DESC:-<No description available>}"
	done
	echo
	exit 1
}

if [ $# -ne 1 -o "$1" == "-h" -o "$1" == "--help" ]
then
	print_help
elif [ ! -e "$configdir/$1" ]
then
	echo "ERROR: \`$configdir/$1' not found."
	print_help
fi

. "$configdir/$1"

# Color codes
fg_BLACK="$(tput setaf 0)"
fg_RED="$(tput setaf 1)"
fg_GREEN="$(tput setaf 2)"
fg_YELLOW="$(tput setaf 3)"
fg_BLUE="$(tput setaf 4)"
fg_MAGENTA="$(tput setaf 5)"
fg_CYAN="$(tput setaf 6)"
fg_WHITE="$(tput setaf 7)"
fg_BOLD="$(tput bold)"
color_reset="$(tput sgr0)"

# Underline is slightly different
fg_UNDERLINE="$(tput smul)"
underline_reset="$(tput rmul)"

while read line
do
	sedcmd=''
	for c in GREEN BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE BOLD UNDERLINE
	do
		if [ $c == UNDERLINE ]
		then
			reset="$underline_reset"
		else
			reset="$color_reset"
		fi

		eval "words=(\"\${$c[@]}\")"
		for w in "${words[@]}"
		do
			sedcmd="${sedcmd}s/($w)/$(eval "echo \$fg_$c")\1$reset/g;"
		done
	done
	echo "$line"|sed -r "$sedcmd"
done

