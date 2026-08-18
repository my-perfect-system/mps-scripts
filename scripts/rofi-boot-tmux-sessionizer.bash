#!/bin/bash


THEME_FOLDER=/usr/share/rofi/themes
THEME_NAME=rofi-boot-launcher.rasi
tmux="tmux:~/.local/bin/rofi-boot-tmux.bash"
tmuxinator="tmuxinator:~/.local/bin/rofi-boot-tmuxinator.bash"
rofi -modi "$tmuxinator,$tmux" -show tmux \
    -theme "$THEME_FOLDER/$THEME_NAME"
