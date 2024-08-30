#!/bin/bash

# Define the directory to watch and the rclone remote/target
WATCH_DIR="/home/coder/revconductor"
RCLONE_REMOTE="codeserver:"

# Initial sync on container start
rclone sync "$WATCH_DIR" "$RCLONE_REMOTE"

# Use inotifywait to monitor the directory for changes
inotifywait -m -r -e modify,create,delete,move "$WATCH_DIR" |
while read -r directory events filename; do
    echo "Change detected: $events in $directory$filename"
    # Perform the sync
    rclone sync "$WATCH_DIR" "$RCLONE_REMOTE"
done