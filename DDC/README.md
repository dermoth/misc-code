# DDC Tool

Tool to control monitors using **Display Data Channel** (DDC).

## Abstract

This tool started from a need to control my monitors using DDC; Since switching
to dark theme, I often get discomfort from any page/presentation/online meeting
using a white background, and needed a quick way to control the backlight.

This a a WIP and many changes are likely coming in the near future. I'm
committing this version so I can start breaking stuff...

## Prerequisites

To use this, you need the `i2c-dev` module. Add the following lines to
/etc/modules:

```conf
# Used to control monitors using ddc
i2c-dev
```

Since the script requires root, you need to use a tool like sudo to execute it
as root. Assuming you already have a `@includedir /etc/sudoers.d` line in your
`/etc/sudoers` file, cou can add/update `/etc/sudoers.d/ddctool` with the
following command:

```sh
printf '0i\n%%users\tALL=(root) NOPASSWD: %s\n\n.\n.,$d\nw\nq\n' "/opt/ddctool.sh" |
    SUDO_EDITOR="ed -s" visudo -f /etc/sudoers.d/ddctool
```

The last argument to printf is the script location, review as needed.

## `ddctool.sh`

TODO - usage may change significantly

## TODO

* Check if udev rules can be used to trigger module load
* Support per-monitor setting
* Add more commands: list, report, etc...
