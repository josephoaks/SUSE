#!/bin/sh

# set variables
base_dir="/mnt/export/updates"

spacewalk-remove-channel -l | sed 's/^[[:space:]]*//' | while IFS= read -r channel; do
  ignore_channels=("rhel" "centos" "res8" "res-" "packagehub")

  ignore=false
  for ignore_pattern in "${ignore_channels[@]}"; do
    if [[ "$channel" == *"$ignore_pattern"* ]]; then
      ignore=true
      break
    fi
  done

  if [ "$ignore" = true ]; then
    echo "Ignoring channel: $channel"
  else
    product_dir="$base_dir/$channel"
    day=$(date -d "6 days ago" +"%Y-%m-%d")
    options="--logLevel=debug --orgLimit=2 --packagesOnlyAfter=$day"

    if [ -d "$product_dir" ] && [ -n "$(ls -A "$product_dir")" ]; then
      echo "Removing contents of $product_dir"
      rm -rf "$product_dir"/*
    else
      mkdir -p "$product_dir"
    fi

    echo "Exporting channel $channel to $product_dir"
    inter-server-sync export --channels="$channel" --outputDir="$product_dir" $options
  fi
done
