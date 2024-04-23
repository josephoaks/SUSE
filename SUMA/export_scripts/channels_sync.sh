#!/bin/sh

# copy the customers output of the `spacewalk-remove-channel -l` to the `channels.txt` file
# and execute this script to add and sync their product to the SUMA Server.

channels_file="channels.txt"

if [ ! -f "$channels_file" ]; then
  echo "Error: channels.txt file not found."
  exit 1
fi

while read -r channel_name; do
  channel_name=$(echo "$channel_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  if [ -n "$channel_name" ]; then
    mgr-sync add channel "$channel_name" --no-sync
  fi
done < "$channels_file"

mgr-sync refresh --refresh-channels
