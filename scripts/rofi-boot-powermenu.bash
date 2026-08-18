#!/bin/bash

THEME_FOLDER=/usr/share/rofi/themes
THEME_NAME=rofi-boot-powermenu.rasi

CMD=sudo
DISTRO=$(lsb-release -si)
if [ "$DISTRO" = "Arch" ]; then
    CMD=gksudo
else
    CMD="sudo -A"
    SUDO_ASKPASS=$(which ssh-askpass)
    export SUDO_ASKPASS=$SUDO_ASKPASS
fi
chosen=$(printf "Power Off\nRestart\nLogout\nLock\n" | rofi -dmenu -theme $THEME_FOLDER/$THEME_NAME)
case "$chosen" in
"Power Off") $CMD poweroff ;;
"Restart") $CMD reboot ;;
"Logout") kill -9 -1 ;;
"Lock") lxlock ;;
*) false ;;
esac
