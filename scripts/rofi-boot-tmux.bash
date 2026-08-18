#!/bin/bash
if [ -z "$1" ]; then
	tmux list-sessions -F "#{session_name}" 2>/dev/null || echo "No sessions"
else
	tmux switch-client -t "$1" 2>/dev/null || tmux attach -t "$1"|| tmuxinator start "$1"
fi
