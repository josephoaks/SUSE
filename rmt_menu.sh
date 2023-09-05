#!/bin/bash

# The purpose of this script is to set specific products
# to rmt-cli sync for SLE products

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <product> <release> <arch>"
  echo "  Product Options: SLES SLED"
  echo "  Release Options: 15, 12, 11"
  echo "  Architecture Options: x86_64, aarch64, s390x, ppc64le, amd64, ia64, i386, i486, i586, i686, ppc64, s390, ppc"
  exit 1
fi

# Set variables
prod="$1"
rel="$2"
arch="$3"
if [ $prod == "SLES" ]; then
  product="SUSE Linux Enterprise Server"
  else
  product="SUSE Linux Enterprise Desktop"
fi

# Define the Service Pack versions
getsp=$(egrep "$product\s+\|.*\s+$rel.*$arch" prod_list.txt | awk -F '|' '{print $4}' | sort -u)
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
          rmt-cli products enable "$(egrep "$product\s+\|.*$selected_option.*$arch" prod_list.txt | awk -F '| ' '{printf "%s ",$2}')"
      else
        echo "Selected: $product $selected_option $arch"
          echo "egrep "$product\s+\|.*$selected_option.*$arch" prod_list.txt | awk -F '| ' '{printf "%s ",$2}'"
          rmt-cli products enable "$(egrep "$product\s+\|.*$selected_option.*$arch" prod_list.txt | awk -F '| ' '{printf "%s ",$2}')"
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
