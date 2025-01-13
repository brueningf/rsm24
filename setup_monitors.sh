#!/bin/bash

# Name of the current tmux session
SESSION=$(tmux display-message -p "#S")

# Save the current window index
CURRENT_WINDOW=$(tmux display-message -p "#I")

# Check if a tmux session is active
if [ -z "$SESSION" ]; then
  echo "No active tmux session found."
  exit 1
fi

# Create the first new window with two panes
tmux new-window -t "$SESSION" -n "USB0-Monitor"
tmux split-window -h -t "$SESSION:USB0-Monitor"
tmux select-pane -t "$SESSION:USB0-Monitor.1" # Move to the second pane
tmux send-keys "jag monitor -p /dev/ttyUSB0" C-m # Run command
tmux select-pane -t "$SESSION:USB0-Monitor.0" # Switch back to the first pane

# Create the second new window with two panes
tmux new-window -t "$SESSION" -n "USB1-Monitor"
tmux split-window -h -t "$SESSION:USB1-Monitor"
tmux select-pane -t "$SESSION:USB1-Monitor.1" # Move to the second pane
tmux send-keys "jag monitor -p /dev/ttyUSB1" C-m # Run command
tmux select-pane -t "$SESSION:USB1-Monitor.0" # Switch back to the first pane

# Switch back to the original window
tmux select-window -t "$SESSION:$CURRENT_WINDOW"

