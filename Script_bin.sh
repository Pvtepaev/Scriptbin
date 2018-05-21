#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "$(id -u)" != "0" ]; then
        echo "This script must be executed as root. Exiting" >&2
        exit 1
fi

Fex2Bin="$(which fex2bin)"
if [ "X${Fex2Bin}" = "X" ]; then
        apt-get -f -q -y install sunxi-tools
fi

Path2ScriptBin="$(df | awk -F" " '/^\/dev\/mmcblk0p1/ {print $6}')"
if [ ! -f "${Path2ScriptBin}/script.bin" ]; then
        echo "Can not find script.bin. Ensure boot partition is mounted" >&2
        exit 1
fi

MyTmpFile="$(mktemp /tmp/${0##*/}.XXXXXX)"
trap "rm \"${MyTmpFile}\" ; exit 0" 0 1 2 3 15

bin2fex <"${Path2ScriptBin}/script.bin" | grep -v "^LV" | grep -v "^max_freq" | grep -v "^min_freq" | grep -v "^extremity_freq" >"${MyTmpFile}"
if [ $? -ne 0 ]; then
        echo "Could not convert script.bin to fex. Exiting" >&2
        exit 1
fi
cp -p "${Path2ScriptBin}/script.bin" "${Path2ScriptBin}/script.bin.bak"

sed -i '/\[dvfs_table\]/a \
extremity_freq = 1296000000\
max_freq = 1200000000\
min_freq = 480000000\
LV_count = 7\
LV1_freq = 1296000000\
LV1_volt = 1320\
LV2_freq = 1200000000\
LV2_volt = 1240\
LV3_freq = 1104000000\
LV3_volt = 1180\
LV4_freq = 1008000000\
LV4_volt = 1140\
LV5_freq = 960000000\
LV5_volt = 1080\
LV6_freq = 816000000\
LV6_volt = 1020\
LV7_freq = 480000000\
LV7_volt = 980' "${MyTmpFile}"

fex2bin "${MyTmpFile}" "${Path2ScriptBin}/script.bin" >/dev/null
if [ $? -ne 0 ]; then
        mv "${Path2ScriptBin}/script.bin.bak" "${Path2ScriptBin}/script.bin"
        echo "Writing script.bin went wrong. Nothing changed" >&2
        exit 1
fi
echo "Successfully repaired broken overvolting/overclocking settings. Reboot necessary for changes to take effect"
