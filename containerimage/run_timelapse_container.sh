#!/bin/bash

set -o pipefail

# Example command for running on rpi3.
# External storage drive mounted on host to /mnt/timelapse
# Camera passed through to container (check bus/device)

# Fuji X-T1 device ID 04cb:02bf
USB_CAMERA="04cb:02bf"
device=$(lsusb -d "$USB_CAMERA" | sed -r 's#Bus (\d{3}) Device (\d{3}).*#/dev/bus/usb/\1/\2#')

if [ $? -ne 0 ] || [ -z "$device" ]; then
    echo "Unable to find X-T1 USB device."
    exit 1
fi

sudo docker run -it --rm --name timelapse -v /mnt/timelapse:/storage --device="$device" r.xe2.io/timelapse:stretch-aarch64 bash
