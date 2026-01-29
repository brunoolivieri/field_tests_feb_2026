#!/bin/bash

# rollbackmaker.sh - Creates a rollback script for the network configuration
# This script snapshots the current network state and generates 'rollback.sh'

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

BACKUP_DIR="./backup"
mkdir -p "$BACKUP_DIR"

echo "Snapshotting configuration to $BACKUP_DIR..."

# Snapshot iptables
iptables-save > "$BACKUP_DIR/iptables.rules"

# Snapshot resolved.conf
cp /etc/systemd/resolved.conf "$BACKUP_DIR/resolved.conf"

# Snapshot sysctl if it exists (for ip_forward)
if [ -f /etc/sysctl.d/99-gs-router.conf ]; then
    cp /etc/sysctl.d/99-gs-router.conf "$BACKUP_DIR/99-gs-router.conf"
fi

# Snapshot NM connections
# We just list them to know what was active. 
# Recreating exact NM profiles is hard, but we can try to save the active connection on eth0 if any.
ETH0_CON=$(nmcli -t -f UUID,DEVICE con show | grep ":eth0" | cut -d: -f1)
if [ -n "$ETH0_CON" ]; then
    echo "$ETH0_CON" > "$BACKUP_DIR/eth0_connection_uuid"
fi

# Create the rollback script
cat <<EOF > rollback.sh
#!/bin/bash

if [ "\$EUID" -ne 0 ]; then
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
if [ -f "$BACKUP_DIR/iptables.rules" ]; then
    iptables-restore < "$BACKUP_DIR/iptables.rules"
else
    # Fallback cleanup
    iptables -F
    iptables -t nat -F
fi

# 3. Restore sysctl
rm -f /etc/sysctl.d/99-gs-router.conf
sysctl --system

# 4. Restore DNS
if [ -f "$BACKUP_DIR/resolved.conf" ]; then
    cp "$BACKUP_DIR/resolved.conf" /etc/systemd/resolved.conf
    systemctl restart systemd-resolved
fi

# 5. Restore eth0 configuration
# Delete gs-eth0
nmcli con delete gs-eth0 2>/dev/null

# Attempt to restore previous connection if we knew it
if [ -f "$BACKUP_DIR/eth0_connection_uuid" ]; then
    UUID=\$(cat "$BACKUP_DIR/eth0_connection_uuid")
    nmcli con up "\$UUID" 2>/dev/null
else
    # Try to auto-connect any available profile or set to auto
    nmcli dev set eth0 managed yes
    nmcli dev connect eth0 2>/dev/null
fi

echo "Rollback completed."
EOF

chmod +x rollback.sh
echo "rollback.sh created successfully."
