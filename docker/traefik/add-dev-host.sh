#!/bin/bash
# Add a *.dev.local hostname to /etc/hosts
# Usage: ./add-dev-host.sh myproject
#        Creates: myproject.dev.local -> 127.0.0.2

if [ -z "$1" ]; then
    echo "Usage: $0 <project-name>"
    echo "Example: $0 league-draft-website"
    exit 1
fi

HOST="$1.dev.local"

if grep -q "$HOST" /etc/hosts 2>/dev/null; then
    echo "Already exists: $HOST"
else
    echo "127.0.0.2 $HOST" | sudo tee -a /etc/hosts > /dev/null
    echo "Added: $HOST -> 127.0.0.2"
fi
