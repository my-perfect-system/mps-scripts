#!/bin/bash
ARG="$1"
if [ -z "$ARG" ]; then
	for f in ~/.config/tmuxinator/*.yml; do
		[ -f "$f" ] && basename "$f" .yml
	done
else

	# tmux switch-client -t "$1" 2>/dev/null || tmux attach -t "$1"
	if tmux list-sessions | grep -E "^$ARG:" &>/dev/null; then
		if ! tmux switch-client -t "$1" 2>/dev/null ; then
			kitty tmux attach -t "$1" &
		fi
		killall rofi # dirty hack, as rofi blocks
	else
		kitty tmuxinator start "$1" &
		killall rofi # dirty hack, as rofi blocks
	fi
fi
