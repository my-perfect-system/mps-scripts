#!/bin/bash

THEME_FOLDER=/usr/share/rofi/themes
THEME_NAME=rofi-boot-launcher.rasi
tmux="tmux:~/.local/bin/rofi-boot-tmux.bash"
rofi -modi drun,run,window,"$tmux",filebrowser,ssh,keys -show drun \
    -theme "$THEME_FOLDER/$THEME_NAME"
