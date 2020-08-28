#!/bin/bash

if [ -d /sys/firmware/efi ]; then
	DEVICE=$( sed -r 's/.*root=UUID=(\S+).*/\1/' /proc/cmdline )
	efibootmgr -c -d /dev/disk/by-uuid/$DEVICE -p 2 -L "sapb1hana" -l \\EFI\\sles\\grubx64.efi
fi
