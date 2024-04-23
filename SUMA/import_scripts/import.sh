#!/bin/sh

yaml_file="/mnt/import/scripts/rgsimportexport.yaml"
user='rsyncuser'
host=$(awk '/^host:/ { print $2 }' "$yaml_file")
pass=$(awk '/^pass:/ { print $2 }' "$yaml_file")
uname='rgsimportexport'
basedir='/mnt/import'

options="--xmlRpcUser=$uname --xmlRpcPassword=$pass --logLevel=error"

log_dir="/mnt/logs"
log_file="${log_dir}/$(date +"%Y-%m-%d")-import.log"

if [ ! -d "$log_dir" ]; then
  mkdir -p "$log_dir"
fi

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$log_file"
}

rm -rf "$basedir"/updates/*
rm -rf "$basedir"/initial/*
rsync -avP -e 'ssh -i /home/rsyncuser/.ssh/id_rsa' "${user}@${host}":/ "$basedir"

process_directory() {
  if [ -z "$(find "$1" -mindepth 1 -type d -print -quit)" ]; then
    dir_name=$(basename "$1")
    log "No imports at this time for $dir_name."
    return
  fi

  for dir in "$1"/*; do
    if [ -d "$dir" ]; then
      inter-server-sync import --importDir="$dir" $options >> "$log_file" 2>&1
      log "Import for directory $dir completed."
    fi
  done
}

process_directory "$basedir/updates"
process_directory "$basedir/initial"
