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
fg_BLACK="$(echo -e '\e[30m')"
fg_RED="$(echo -e '\e[31m')"
fg_GREEN="$(echo -e '\e[32m')"
fg_YELLOW="$(echo -e '\e[33m')"
fg_BLUE="$(echo -e '\e[34m')"
fg_MAGENTA="$(echo -e '\e[35m')"
fg_CYAN="$(echo -e '\e[36m')"
fg_WHITE="$(echo -e '\e[37m')"
color_reset="$(echo -e '\e[39m')"

# Bold and Underline are slightly different
fg_BOLD="$(echo -e '\e[1m')"
bold_reset="$(echo -e '\e[0m')"

fg_UNDERLINE="$(echo -e '\e[4m')"
underline_reset="$(echo -e '\e[0m')"

sedcmd=''
for c in GREEN BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE BOLD UNDERLINE
do
	case $c in
		BOLD)
			reset="$bold_reset"
			;;
		UNDERLINE)
			reset="$underline_reset"
			;;
		*)
			reset="$color_reset"
	esac

	eval "words=(\"\${$c[@]}\")"
	for w in "${words[@]}"
	do
		sedcmd="${sedcmd}s/($w)/$(eval "echo \$fg_$c")\1$reset/g;"
	done
done

exec sed -r "$sedcmd"

