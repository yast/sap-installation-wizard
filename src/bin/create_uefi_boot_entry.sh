#!/bin/bash

if [ -d /sys/firmware/efi ]; then
	PUUID=$( sed -r 's/.*root=UUID=(\S+).*/\1/' /proc/cmdline )
	PART=$( readlink -f /dev/disk/by-uuid/${PUUID} )
	DEVICE=${PART/p[0-9]/}
	if [ "${DEVICE}" == "${PART}" ]; then
	    DEVICE=${PART/[0-9]/}
	fi
	efibootmgr -c -d $DEVICE -p 2 -L "sapb1hana" -l \\EFI\\BOOT\\GRUBX64.EFI
fi
