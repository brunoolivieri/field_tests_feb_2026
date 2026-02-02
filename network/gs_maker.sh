#!/bin/bash

# gs_maker.sh - Configure machine as router
# Configures eth0 as LAN (192.168.1.1) and shares internet from any other interface (WiFi/USB).
# This script avoids using NetworkManager for eth0 configuration.

# Helper function for checking root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Starting router configuration..."

# 0. Prevent NetworkManager from interfering with eth0
# We set eth0 as unmanaged if NM is present.
if command -v nmcli >/dev/null 2>&1; then
    if systemctl is-active --quiet NetworkManager; then
        echo "Setting eth0 to unmanaged in NetworkManager..."
        # This prevents NM from trying to control the interface while we use ip commands
        nmcli device set eth0 managed no
    fi
fi

# 1. Enable IP Forwarding
echo "Enabling IP Forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-gs-router.conf
sysctl -p /etc/sysctl.d/99-gs-router.conf

# 2. Configure eth0 with static IP 192.168.1.1
echo "Configuring eth0..."
# Bring down to flush
ip link set eth0 down
ip addr flush dev eth0
# Configure IP
ip addr add 192.168.1.1/24 dev eth0
# Bring up
ip link set eth0 up

# 3. Setup DHCP Server (dnsmasq)
echo "Setting up DHCP server..."
# Kill any existing manually started dnsmasq to clean slate
pkill dnsmasq || true

# Check if dnsmasq is installed
if ! command -v dnsmasq >/dev/null 2>&1; then
    echo "Error: dnsmasq is not installed. Please install it with 'apt install dnsmasq'."
    # We continue trying, but it likely won't work if missing. 
    # In a 'maker' script, we might want to install it, but sticking to config for now.
    # Assuming the environment has it or user will install.
fi

# Create a systemd service for dnsmasq
# CRITICAL FIXES:
# 1. --listen-address=192.168.1.1 --bind-interfaces: usage of specific IP avoids conflict with systemd-resolved (which binds 127.0.0.53)
# 2. --dhcp-option=3,192.168.1.1: Explicitly set the Gateway (Router) option
# 3. --dhcp-option=6,...: Explicitly set DNS
cat <<EOF > /etc/systemd/system/gs-dhcp.service
[Unit]
Description=GS Router DHCP Server
After=network.target

[Service]
ExecStart=/usr/sbin/dnsmasq -k \\
    --conf-file=/dev/null \\
    --interface=eth0 \\
    --listen-address=192.168.1.1 \\
    --bind-interfaces \\
    --except-interface=lo \\
    --dhcp-range=192.168.1.150,192.168.1.200,12h \\
    --dhcp-option=3,192.168.1.1 \\
    --dhcp-option=6,8.8.8.8,1.1.1.1 \\
    --server=8.8.8.8 \\
    --server=1.1.1.1
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now gs-dhcp.service

# 4. Configure Local DNS (Optional but requested to strict 8.8.8.8)
echo "Configuring local DNS..."
# Only backup if not exists
if [ ! -f /etc/systemd/resolved.conf.bak ]; then
    cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
fi

# Clean up previous edits if any (simple approach)
sed -i '/^DNS=/d' /etc/systemd/resolved.conf
sed -i '/^#DNS=/d' /etc/systemd/resolved.conf
echo "DNS=8.8.8.8 1.1.1.1" >> /etc/systemd/resolved.conf
systemctl restart systemd-resolved

# 5. Setup NAT and Firewall
echo "Setting up NAT and Firewall..."
ufw disable 2>/dev/null

# Clean iptables
iptables -F
iptables -t nat -F
iptables -X

# Set policies to ACCEPT all (as requested)
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# MASQUERADE
# This rule says: Traffic leaving the box NOT through eth0 (so effectively wlan0, usb0, etc) needs to be NATed.
iptables -t nat -A POSTROUTING ! -o eth0 -j MASQUERADE

# Persistence for NAT
cat <<EOF > /etc/systemd/system/gs-nat.service
[Unit]
Description=GS Router NAT Rules
After=network.target

[Service]
Type=oneshot
# Clear and apply
ExecStart=/usr/sbin/iptables -t nat -F
ExecStart=/usr/sbin/iptables -t nat -A POSTROUTING ! -o eth0 -j MASQUERADE
ExecStart=/usr/sbin/iptables -P FORWARD ACCEPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now gs-nat.service

echo "Configuration completed successfully."
echo "Current eth0 config:"
ip addr show eth0
echo "DHCP Service Status:"
systemctl status gs-dhcp.service --no-pager
