#!/bin/bash
# WSL2 dnsmasq boot script
# Configures dnsmasq with dynamic WSL IP and dev.local routing

# Wait for network to be ready
until ip addr show eth0 | grep -q "inet "; do
    sleep 1
done

# Get WSL IP (changes on each boot)
WSL_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

# Get the original WSL DNS server before we modify resolv.conf
WSL_DNS=$(grep nameserver /etc/resolv.conf 2>/dev/null | head -1 | awk '{print $2}')
WSL_DNS=${WSL_DNS:-10.255.255.254}

# Create dnsmasq config with upstream DNS
cat > /etc/dnsmasq.d/upstream.conf << EOF
# Upstream DNS servers
server=8.8.8.8
server=1.1.1.1
server=${WSL_DNS}
EOF

# Local dev routing - *.dev.local -> 127.0.0.1
cat > /etc/dnsmasq.d/dev.local.conf << EOF
address=/dev.local/127.0.0.1
EOF

# Listen on both localhost and WSL IP (for Windows to reach us)
cat > /etc/dnsmasq.d/local.conf << EOF
listen-address=127.0.0.1,${WSL_IP}
bind-interfaces
cache-size=1000
EOF

# Start dnsmasq
systemctl restart dnsmasq

# Point resolv.conf to dnsmasq with fallback
rm -f /etc/resolv.conf
cat > /etc/resolv.conf << EOF
nameserver 127.0.0.1
nameserver 8.8.8.8
EOF

# Log the IP for reference (useful for Windows DNS config)
echo "WSL dnsmasq ready on ${WSL_IP}" > /run/dnsmasq-wsl-ip
echo "${WSL_IP}" > /run/wsl-ip
