#!/bin/bash

# gs_maker.sh - Configure machine as router
# This script configures the machine to share internet from Any interface to eth0.
# It sets eth0 to 192.168.1.1, enables DHCP, and NAT.

# Helper function for checking root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Starting router configuration..."

# 1. Enable IP Forwarding
echo "Enabling IP Forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-gs-router.conf
sysctl --system

# 2. Configure eth0 with static IP 192.168.1.1
echo "Configuring eth0..."
# Use nmcli if available and active
if systemctl is-active --quiet NetworkManager; then
    # Remove existing gs-eth0 if it exists
    if nmcli con show "gs-eth0" &> /dev/null; then
        nmcli con delete "gs-eth0"
    fi
    # Create new connection
    nmcli con add type ethernet ifname eth0 con-name gs-eth0 \
        ipv4.method manual ipv4.addresses 192.168.1.1/24 \
        ipv4.gateway "" ipv4.dns "" 
    nmcli con up gs-eth0
else
    # Fallback to ip link/addr if NM is not active (though instructions say it is)
    ip link set eth0 up
    ip addr flush dev eth0
    ip addr add 192.168.1.1/24 dev eth0
fi

# 3. Setup DHCP Server (dnsmasq)
echo "Setting up DHCP server..."
# We use a standalone dnsmasq service to ensure exact configuration
# Kill any existing dnsmasq manually started? (Risk of killing system one, but we are root and setting up router)
# We will use a systemd service to manage it safely.

cat <<EOF > /etc/systemd/system/gs-dhcp.service
[Unit]
Description=GS Router DHCP Server
After=network.target

[Service]
ExecStart=/usr/sbin/dnsmasq -k --conf-file=/dev/null --interface=eth0 --bind-interfaces --except-interface=lo --dhcp-range=192.168.1.150,192.168.1.200,12h --dhcp-option=6,8.8.8.8,1.1.1.1 --server=8.8.8.8 --server=1.1.1.1
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now gs-dhcp.service

# 4. Configure Local DNS
echo "Configuring local DNS..."
# Backup resolved.conf if not already backed up by rollbackmaker (we assume we can overwrite or edit)
if [ ! -f /etc/systemd/resolved.conf.bak ]; then
    cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
fi

# Ensure DNS settings
# We use sed to ensure DNS=8.8.8.8 1.1.1.1 is set
sed -i '/^DNS=/d' /etc/systemd/resolved.conf
sed -i '/^#DNS=/d' /etc/systemd/resolved.conf
echo "DNS=8.8.8.8 1.1.1.1" >> /etc/systemd/resolved.conf
systemctl restart systemd-resolved

# 5. Setup NAT and Firewall
echo "Setting up NAT and Firewall..."
# Disable UFW as requested ("All network traffic shall be accepted")
ufw disable

# Flush iptables to clean state (optional, but ensures "accept with no restrictions")
iptables -F
iptables -t nat -F
iptables -X

# Set policies
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Enable Masquerade for anything leaving the machine NOT on eth0 (so wifi, usb, etc)
iptables -t nat -A POSTROUTING ! -o eth0 -j MASQUERADE

# Persistence for NAT
cat <<EOF > /etc/systemd/system/gs-nat.service
[Unit]
Description=GS Router NAT Rules
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/iptables -t nat -A POSTROUTING ! -o eth0 -j MASQUERADE
ExecStart=/usr/sbin/iptables -P FORWARD ACCEPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now gs-nat.service

echo "Configuration completed successfully."
