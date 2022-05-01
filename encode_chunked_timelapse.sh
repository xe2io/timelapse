#!/bin/env bash

# Script to encode folders of jpgs as chunks, then concatenates chunks into final timelapse file
# main use case is DJI Osmo Action format, folder of 999 images.

function cleanup {
    rm -f "$input_file" 2>/dev/null
}

trap cleanup EXIT

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $(realpath $0)) <output filename>"
    exit 1
fi

output_file="$1"

# TODO: intelligently figure out parallel ffmpeg
ls -1 | xargs -P8 -I{} ffmpeg -framerate 60 -pattern_type glob -i '{}/*.JPG' -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1" -c:v libx264 -crf 23 -pix_fmt yuv420p -movflags +faststart chunk_{}_crf23.mp4
input_file=$(mktemp input_XXXXXXXX)
ls chunk_*.mp4 | xargs -I{} echo file \'{}\' >> "$input_file"

ffmpeg -f concat -i "$input_file" -c copy "$output_file"
