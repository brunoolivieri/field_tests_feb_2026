#!/bin/bash
# remove_gs_services.sh - Remove serviços criados pelo gs_maker.sh e restaura configurações

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root (sudo)."
  exit 1
fi

echo "=== Iniciando remoção dos serviços GS ==="

# 1. Remover Serviço DHCP
if systemctl list-units --full -all | grep -q "gs-dhcp.service"; then
    echo "Parando e desabilitando gs-dhcp.service..."
    systemctl stop gs-dhcp.service
    systemctl disable gs-dhcp.service
    rm -f /etc/systemd/system/gs-dhcp.service
    echo "gs-dhcp.service removido."
else
    echo "gs-dhcp.service não encontrado ou já removido."
fi

# 2. Remover Serviço NAT
if systemctl list-units --full -all | grep -q "gs-nat.service"; then
    echo "Parando e desabilitando gs-nat.service..."
    systemctl stop gs-nat.service
    systemctl disable gs-nat.service
    rm -f /etc/systemd/system/gs-nat.service
    # Limpar regras de NAT aplicadas
    iptables -t nat -F
    echo "gs-nat.service removido e regras NAT limpas."
else
    echo "gs-nat.service não encontrado ou já removido."
fi

# 3. Restaurar DNS (resolved.conf)
if [ -f /etc/systemd/resolved.conf.bak ]; then
    echo "Restaurando backup do /etc/systemd/resolved.conf..."
    cp /etc/systemd/resolved.conf.bak /etc/systemd/resolved.conf
    systemctl restart systemd-resolved
    echo "Configuração de DNS restaurada."
else
    echo "Backup do resolved.conf não encontrado. Nenhuma alteração feita no DNS."
fi

# 4. Recarregar systemd
systemctl daemon-reload
echo "=== Remoção Concluída ==="
