#!/bin/bash

# Copyright (C) 2025 Navotpala Tech
#
# SPDX-License-Identifier: BSD-3-Clause

# set -e

# save the official lunch command to aosp_lunch() and source it
tmp_lunch=`mktemp`
TEMP_PATH=$(mktemp -d)

#setup colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
purple=`tput setaf 5`
teal=`tput setaf 6`
light=`tput setaf 7`
dark=`tput setaf 8`
ltred=`tput setaf 9`
ltgreen=`tput setaf 10`
ltyellow=`tput setaf 11`
ltblue=`tput setaf 12`
ltpurple=`tput setaf 13`
CL_CYN=`tput setaf 12`
CL_RST=`tput sgr0`
reset=`tput sgr0`

# grab path for this script
SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
vendor_name=bass

target_dir=bootable/aaropa
prebuilts=prebuilts/aaropa/rootfs/installer/$vendor_name

# Copy files from $prebuilts
cp -rft $target_dir/initrd $prebuilts/initrd/.
cp -rft $target_dir/iso $prebuilts/iso/. $prebuilts/install.sfs
cp -ft $target_dir $prebuilts/boot_hybrid.img

# Create overlay folders
mkdir -p $target_dir/iso/overlay/{etc/calamares/{branding/$vendor_name,resources/modules/presets/icon},root/{.themes,.backgrounds}}