#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Rolling back configuration..."

# 1. Stop and remove services created by gs_maker
systemctl disable --now gs-dhcp.service 2>/dev/null
rm -f /etc/systemd/system/gs-dhcp.service
systemctl disable --now gs-nat.service 2>/dev/null
rm -f /etc/systemd/system/gs-nat.service
systemctl daemon-reload

# 2. Restore iptables
if [ -f "./backup/iptables.rules" ]; then
    iptables-restore < "./backup/iptables.rules"
else
    # Fallback cleanup
    iptables -F
    iptables -t nat -F
fi

# 3. Restore sysctl
rm -f /etc/sysctl.d/99-gs-router.conf
sysctl --system

# 4. Restore DNS
if [ -f "./backup/resolved.conf" ]; then
    cp "./backup/resolved.conf" /etc/systemd/resolved.conf
    systemctl restart systemd-resolved
fi

# 5. Restore eth0 configuration
# Delete gs-eth0
nmcli con delete gs-eth0 2>/dev/null

# Attempt to restore previous connection if we knew it
if [ -f "./backup/eth0_connection_uuid" ]; then
    UUID=$(cat "./backup/eth0_connection_uuid")
    nmcli con up "$UUID" 2>/dev/null
else
    # Try to auto-connect any available profile or set to auto
    nmcli dev set eth0 managed yes
    nmcli dev connect eth0 2>/dev/null
fi

echo "Rollback completed."
