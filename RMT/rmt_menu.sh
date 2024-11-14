#!/bin/bash

##################################################
# Written by: Joseph Oaks                        #
# Date: 15 Nov 2023                              #
# Purpose: This script allows a user to select   #
#          SUSE Products to enable for use in    #
#          the RMT Server.                       #
#                                                #
# Instructions:                                  #
# To add a new product, simply add the product   #
# name to the product array and execute.         #
# When a product version is EOL you can modify   #
# the awk statement to ignore that version as    #
# an example:                                    #
# `if (!($4 ~ /^10( SP[0-9]+)?$/ || $4 == "9"))` #
# here it is looking for anything that matches   #
# "9", "10" or any combination of "10 SP{1,2,3}" #
##################################################

################################
# Product names to choose from #
################################
product=("SUSE Linux Enterprise Server"
	 "SUSE Linux Enterprise Desktop"
	 "SUSE Linux Enterprise Server LTSS"
	 "SUSE Linux Enterprise Live Patching"
	 "SUSE Manager Server"
	 "SUSE Linux Enterprise Micro"
         "SUSE Linux Enterprise Workstation Extension"
	 "SUSE Package Hub")

#####################################
# RMT Commands to simplify the code #
#####################################
rmte="rmt-cli products enable"
rmtl="rmt-cli products list --all"

##############
# User input #
##############
selected_products=()
selected_releases=()
selected_architectures=()

##############################
# Product Selection Function #
##############################
select_product() {
  echo "Select a product:"
  select product_choice in "${product[@]}" "Exit"; do
    if [ "$product_choice" == "Exit" ]; then
      echo "Exiting."
      exit 0
    elif [ -n "$product_choice" ]; then
      selected_product=("$product_choice")
    fi
    break
  done
}

##############################
# Release Selection Function #
##############################
select_release() {
  if [[
        "$selected_product" == "SUSE Linux Enterprise Server" ||
        "$selected_product" == "SUSE Linux Enterprise Desktop"
     ]]; then
    releases=$(${rmtl} |
               grep -E "$selected_product\s+\|" |
	       awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4);
	         if (!($4 ~ /^10( SP[0-9]+)?$/ || $4 == "9")) print $4}' |
               sort -uf)
  else
    releases=$(${rmtl} |
               grep -E "$selected_product\s+\|" |
               awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}' |
               sort -uf)
  fi
  possible_releases=()

  while IFS= read -r line; do
    possible_releases+=("$line")
  done <<< "$releases"

  possible_releases+=("All Releases")

  echo "Select a release for $selected_product"
  select release_choice in "${possible_releases[@]}"; do
    if [ "$release_choice" == "All Releases" ]; then
      export selected_release="All"
    else
      export selected_release=$release_choice
    fi
    break
  done
}

###################################
# Architecture Selection Function #
###################################
select_architecture() {
  if [ "$selected_release" == "All" ]; then
    arch=$(${rmtl} |
           grep -E "$selected_product\s+\|" |
           awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); if ($5 !~ /^ {9}$/) print $5}' |
           sort -u)
  else
    arch=$(${rmtl} |
           grep -E "$selected_product\s+\|.*$selected_release" |
           awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); if ($5 !~ /^ {9}$/) print $5}' |
           sort -u)
  fi

  architecture=()

  while IFS= read -r line; do
    architecture+=("$line")
  done <<< "$arch"

  architecture+=("All Architectures")

  echo "Select an architecture for $selected_product $selected_release"
  select arch_choice in "${architecture[@]}"; do
    if [ "$arch_choice" == "All Architectures" ]; then
      selected_architectures="All"
    else
      selected_architectures=("$arch_choice")
    fi
    break
  done
}

####################
# Execute Function #
####################
execute_command() {
  selected_product="$1"
  selected_release="$2"
  selected_architecture="$3"
  command

  echo "Selected product: $selected_product"
  echo "Selected release: $selected_release"
  echo "Selected architecture: $selected_architectures"

  if [[ "$selected_release" == "All" && "$selected_architectures" == "All" ]]; then
    command="$($rmtl | grep -E "$selected_product\s+\|" | awk -F '| ' '{printf "%s ",$2}' | xargs -I {} $rmte {})"
  else
    command="$($rmtl | grep -E "$selected_product\s+\|.*$selected_release.*$selected_architectures" | awk -F '| ' '{printf "%s ",$2}' | xargs -I {} $rmte {})"
  fi

  echo "Executing command: $command"
  sleep 10
  clear_screen
}

clear_screen() {
  clear
}

#############
# Main flow #
#############
while true; do
  select_product
  select_release
  select_architecture
  execute_command "$product_choice" "$release_choice" "$arch_choice"

  echo "Do you want to select another product? (yes/no)"
  read answer
  [[ "$answer" != "yes" ]] && { echo "Exiting."; exit 0; }
done
