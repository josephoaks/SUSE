#!/bin/bash

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <product> <release> <arch>"
  echo "  Product Options: SLES SLED LTSS LivePatch SUMA Micro"
  echo "  Release Options: 15, 12, 11, (5 for Micro) (4 for SUMA)"
  echo "  Architecture Options: x86_64, aarch64, s390x, ppc64le, amd64, ia64, i386, i486, i586, i686, ppc64, s390, ppc"
  exit 1
fi

# Set variables
prod="$1"
rel="$2"
arch="$3"
rmte="rmt-cli product enable"
rmtl="rmt-cli product list --all"

case $prod in
  "SLED") product="SUSE Linux Enterprise Desktop";;
  "Micro") product="SUSE Linux Enterprise Micro";;
  "LTSS") product="SUSE Linux Enterprise Server LTSS";;
  "LivePatch") product="SUSE Linux Enterprise Server Live Patching";;
  "SUMA") product="SUSE Manager Server";;
  *) product="SUSE Linux Enterprise Server";;
esac

# Define the Service Pack versions
getsp=$($rmtl | egrep "$product\s+\|.*\s+$rel.*$arch" | awk -F '|' '{print $4}' | sort -u)
IFS=$'\n' read -d '' -r -a options <<< "$(echo "$getsp" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

# Function to clear the screen
clear_screen() {
  clear
}

# Display the menu
show_menu() {
#  clear_screen
  echo "Service Pack Options for $product $rel ($arch):"
  for ((i = 0; i < "${#options[@]}"; i++)); do
    echo "$((i + 1)). $product ${options[i]}"
  done
  echo "q. Quit"
}

# Handle user input
handle_input() {
  read -rp "Select which Service Pack to mirror (1-${#options[@]}) or 'q' to quit: " choice
  case "$choice" in
    [1-${#options[@]}])
      selected_option="${options[choice - 1]}"
      if [ "$selected_option" == "15" ]; then
        echo "Selected: $product ${#options[i]} $arch"
	$rmtl | egrep "$product\s+\|.*$selected_option.*$arch" | awk -F '| ' '{printf "%s ",$2}' | xargs -I {} $rmte {}
      else
        echo "Selected: $product $selected_option $arch"
	$rmtl | egrep "$product\s+\|.*$selected_option.*$arch" | awk -F '| ' '{printf "%s ",$2}' | xargs -I {} $rmte {}
	jq -r ".[\"$product\"][\"$rel\"][\"default\"][]" modules.json | while read line; do
          $rmtl | egrep "$line\s+\|.*$selected_option.*$arch" | awk -F '| ' '{printf "%s ",$2}' | xargs -I {} $rmte {}
        done
      fi
      ;;
    q)
      echo "Exiting the script."
      exit 0
      ;;
    *)
      echo "Invalid option."
      ;;
  esac
}

# Main script
while true; do
  show_menu
  handle_input
done
