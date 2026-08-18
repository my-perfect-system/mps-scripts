#!/bin/bash

THEME_FOLDER=/usr/share/rofi/themes
THEME_NAME=rofi-boot-autorandr.rasi

builtin=$(printf "vertical\nhorizontal\n")
configured="$(autorandr --list)"
chosen=$(printf "%s\n%s" "$configured" "$builtin" | rofi -dmenu -theme $THEME_FOLDER/$THEME_NAME)
if [[ "$chosen" != "" ]]; then
	autorandr -l "$chosen"
fi
