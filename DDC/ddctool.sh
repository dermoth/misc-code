#!/bin/bash
#
# ddctool.sh - Tool to control monitors using DDC
#
# Right now this tool handles only brightness settings - on some monitors
# most setting can be controlled remotely.
#
# To use this, you need the i2c-dev module. Add the following lines to
# /etc/modules:
#
#     # Used to control monitors using ddc
#     i2c-dev
#
# TODO: Check if udev rules can be used to trigger module loads...
#
# The script requires root privileges, which can be granted using sudo. Ex.
# for the users group:
#
#     printf '0i\n%%users\tALL=(root) NOPASSWD: %s\n\n.\n.,$d\nw\nq\n' "/opt/ddctool.sh" | SUDO_EDITOR="ed -s" visudo -f /etc/sudoers.d/ddctool
#
#  TODO: Check if udev rules can be used instead...
#

declare -rx PATH="/bin:/usr/bin"

# Monitors in /sys/class/drm/, ex. card0-DP-1
# Monitor glob match
MON_GLOB='card?-*'

# Under that, I2c bus, like this: /sys/class/drm/card0-DP-1/i2c-8
I2C_PREFIX='i2c-'

# TODO: We should probably match all and handle separately
# For not this works as well anyway...
# Connector names format: card%d-%s-%d (there can be more dashes in %s).
DISPLAYS=(/sys/class/drm/card[0-9]*-*-[0-9]*/i2c-[0-9]*)

# TODO... for now just change brightness
if [ $# -gt 1 ] || [ -n "${1//[0-9]/}" ] || [ "${1:-0}" -gt 100 ]; then
	echo "Usage ${0##*/} [0-100]"
	echo
	echo "Sets brightness level of all connected displays to specified value."
	exit 1
fi

#DISPLAYS=(/sys/class/drm/${MON_GLOB}/${I2C_PREFIX}[0-9]*)
##shellcheck-friendly way?
#mapfile -t DISPLAYS < <(eval "echo /sys/class/drm/${MON_GLOB}/${I2C_PREFIX}[0-9]*")

if [ ${#DISPLAYS[@]} -eq 0 ] || [ ! -e "${DISPLAYS[0]}" ]; then
	echo "No displays detected!"
	exit 1
fi

i=0
for path in "${DISPLAYS[@]}"; do
	((++i))
	i2c_node=${path##*/}
	busnum=${i2c_node#i2c-}
	if [ $# -ne 1 ]; then
		echo "Getting brightness of display #$i"
		ddcutil --bus "$busnum" getvcp 10
	else
		echo "Setting brightness of display #$i to $1"
		ddcutil --bus "$busnum" setvcp 10 "$1" &
	fi
done
wait
