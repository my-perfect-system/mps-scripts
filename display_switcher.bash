#!/bin/bash

CODE_HDMI=0x11
CODE_DPORT=0x0f
BUS_GIGA=4
BUS_ASUS=13
MODE="$1"

set_display_otr() {
	ddcutil --bus "$BUS_GIGA" setvcp 60 "$CODE_HDMI"
	ddcutil --bus "$BUS_ASUS" setvcp 60 "$CODE_DPORT"
}
set_display_hive() {
	ddcutil --bus "$BUS_GIGA" setvcp 60 "$CODE_DPORT"
	ddcutil --bus "$BUS_ASUS" setvcp 60 "$CODE_HDMI"
}

[[ "$MODE" == "" ]] && set_display_otr && exit 0
[[ "$MODE" == "otr" ]] && set_display_otr && exit 0
[[ "$MODE" == "hive" ]] && set_display_hive && exit 0
