#!/bin/bash

DEVICE=$1
# @TODO find a way to automatically get this as it could be different depending on the drive
BLOCK_SIZE=4096

help () {
    echo "Usage: $0 <block_device>

Tests a new drive by running badblocks and comparing SMART data before and afterwards";
    exit 1;
}

if [ -z "$DEVICE" ]; then
    help
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root!"
    exit 1;
fi

DISK_INFO="$(lshw -class disk | grep /dev/sdb -A 5 -B 5 | sed 's/^ *//;s/ *$//')"

echo "You are about to DESTRUCTIVELY test device $DEVICE. Here is the hardware info of the device."

echo "$DISK_INFO"

echo "Are you ready to test this device? This may take a while and will ERASE ALL DATA on the disk."

PROCEED=false
INPUT=""

while [ "$PROCEED" = false ]; do
    echo -n "(Yes/no):"
    read INPUT
    if [[ "$INPUT" = "Yes" ]]; then
        PROCEED=true
    else
        if [[ "$INPUT" = "n" || "$INPUT" = "no" ]]; then
            exit 0;
        else
            echo "Please type 'Yes' or 'no'";
        fi
    fi
done

PRODUCT=$(echo "$DISK_INFO" | grep product | cut -d: -f2 | sed 's/ *//')
VENDOR=$(echo "$DISK_INFO" | grep vendor | cut -d: -f2 | sed 's/ *//')
SERIAL=$(echo "$DISK_INFO" | grep serial | cut -d: -f2 | sed 's/ *//')

RESULTS_PREFIX="$(date --iso-8601=seconds)_${VENDOR}_${PRODUCT}_${SERIAL}"

smartctl -a $DEVICE > "${RESULTS_PREFIX}_smart-before.txt"

echo "SMART DATA:"

cat "${RESULTS_PREFIX}_smart-before.txt"

echo "Starting Badblocks..."

badblocks -wsv -b 4096 $DEVICE 2>&1 | tee "${RESULTS_PREFIX}_badblocks.txt"

smartctl -a $DEVICE > "${RESULTS_PREFIX}_smart-after.txt"

diff -u "${RESULTS_PREFIX}_smart-before.txt" "${RESULTS_PREFIX}_smart-after.txt"