#!/bin/bash

# Timelapse storage should be mounted to /storage
# This script creates the /storage/YYYYmmdd-HHMM directory for storage
# Fuji camera control does not work in this version of gphoto
# Use external trigger/intervolameter and just store files to disk

storage_root="/storage"
startdate=$(date +%Y%m%d-%H%M)

timelapse_dir="$storage_root/$startdate"

mkdir -p "$timelapse_dir"

# Allow hook script for future expansion in order of precedence: /storage/timelapse_hook, /timelapse_hook
hook_script=""

if [ -x "/timelapse_hook" ]; then
    hook_script="/timelapse_hook
fi

if [ -x "storage_root/timelapse_hook" ]; then
    hook_script="$storage_root/timelapse_hook
fi

if [ !-z "$hook_script" ]; then
    echo "Using timelapse hook script: $hook_script"
    HOOK_SCRIPT_ARGS="--hook-script '$hook_script'"
fi

gphoto2 --wait-event-and-download --filename="timelapse_dir"/%6n.%C $HOOK_SCRIPT_ARGS
