#!/bin/bash
# Setup script for dev container hostname routing
# Run once to start Traefik and configure DNS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Starting Traefik reverse proxy..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d

echo "==> Traefik dashboard available at: http://localhost:8080"

# Check if running in WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo ""
    echo "==> WSL detected. Add hostnames to Windows hosts file:"
    echo "    Run as Administrator in PowerShell:"
    echo ""
    echo '    Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 league-draft.dev.local api.league-draft.dev.local"'
    echo ""
    echo "    Or manually edit C:\\Windows\\System32\\drivers\\etc\\hosts"
else
    echo ""
    echo "==> Adding hostnames to /etc/hosts (requires sudo)..."

    # Function to add host entry if not exists
    add_host() {
        if ! grep -q "$1" /etc/hosts 2>/dev/null; then
            echo "127.0.0.1 $1" | sudo tee -a /etc/hosts > /dev/null
            echo "    Added: $1"
        else
            echo "    Already exists: $1"
        fi
    }

    add_host "league-draft.dev.local"
    add_host "api.league-draft.dev.local"
fi

echo ""
echo "==> Setup complete!"
echo ""
echo "To add more projects, add entries like:"
echo "    127.0.0.1 myproject.dev.local api.myproject.dev.local"
echo ""
echo "Then add Traefik labels to your docker-compose.yml:"
echo '    labels:'
echo '      - "traefik.enable=true"'
echo '      - "traefik.http.routers.myproject.rule=Host(\`myproject.dev.local\`)"'
echo '      - "traefik.http.services.myproject.loadbalancer.server.port=3000"'
