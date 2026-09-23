#!/bin/bash
# gs_maker_ephemeral.sh - Configura a máquina como roteador de forma NÃO persistente
# As configurações aplicadas por este script serão perdidas após o reboot.
# Autor: Antigravity Agent

set -e

# Interface cabeada ligada aos drones (LAN) e sua rede.
# A saída para a internet é qualquer outra interface (Wi-Fi, USB, ...).
LAN_IF=enp3s0
LAN_IP=192.168.1.1
LAN_NET=192.168.1.0/24

DNSMASQ_PID=/run/gs-dnsmasq-ephemeral.pid
DNSMASQ_LEASES=/var/dnsmasq-ephemeral.leases
DNSMASQ_LOG=/var/dnsmasq-ephemeral.log

# Verificação de Root
if [ "$EUID" -ne 0 ]; then
  echo "ERRO: Este script precisa ser executado como root."
  exit 1
fi

echo "=== Iniciando Configuração Efêmera de Roteador ==="
echo "Nota: Todas as alterações serão perdidas ao reiniciar."

# 1. IP Forwarding (Alteração em memória apenas)
echo "Habilitando IP Forwarding..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# 2. Configurar $LAN_IF
echo "Configurando $LAN_IF ($LAN_IP)..."

# Evita que o NetworkManager interfira na $LAN_IF
if command -v nmcli >/dev/null 2>&1; then
    echo "Definindo $LAN_IF como não-gerenciada no NetworkManager..."
    nmcli device set "$LAN_IF" managed no || true
fi

# Configuração manual da interface
ip link set "$LAN_IF" down
ip addr flush dev "$LAN_IF"
ip addr add "$LAN_IP/24" dev "$LAN_IF"
ip link set "$LAN_IF" up

# 3. Servidor DHCP (dnsmasq)
echo "Iniciando servidor DHCP (dnsmasq)..."
# Mata apenas a instância iniciada por este script (não outros dnsmasq do sistema,
# como os do libvirt ou do NetworkManager)
if [ -f "$DNSMASQ_PID" ]; then
    kill "$(cat "$DNSMASQ_PID")" 2>/dev/null || true
    rm -f "$DNSMASQ_PID"
fi
# Instâncias antigas iniciadas sem pidfile (versões anteriores deste script)
pkill -f -- "--listen-address=$LAN_IP" || true
sleep 1

# Verifica se dnsmasq está instalado
if ! command -v dnsmasq >/dev/null 2>&1; then
    echo "AVISO: dnsmasq não encontrado. Tentando instalar..."
    apt-get update && apt-get install -y dnsmasq
fi

# Inicia dnsmasq como daemon (processo em background), sem criar serviço systemd
# Configurações passadas via linha de comando
# --no-resolv: não lê /etc/resolv.conf. No Ubuntu ele aponta para o stub do
# systemd-resolved (127.0.0.53), que recusa consultas vindas de 192.168.1.1.
dnsmasq \
    --conf-file=/dev/null \
    --interface="$LAN_IF" \
    --listen-address="$LAN_IP" \
    --bind-interfaces \
    --except-interface=lo \
    --dhcp-range=192.168.1.150,192.168.1.200,12h \
    --dhcp-option=3,"$LAN_IP" \
    --dhcp-option=6,8.8.8.8,1.1.1.1 \
    --no-resolv \
    --server=8.8.8.8 \
    --server=1.1.1.1 \
    --pid-file="$DNSMASQ_PID" \
    --dhcp-leasefile="$DNSMASQ_LEASES" \
    --log-facility="$DNSMASQ_LOG" \
    --log-dhcp

# Verifica se o dnsmasq subiu
if [ -f "$DNSMASQ_PID" ] && kill -0 "$(cat "$DNSMASQ_PID")" 2>/dev/null; then
    echo "dnsmasq iniciado com sucesso (PID: $(cat "$DNSMASQ_PID"))."
else
    echo "ALERTA: O processo dnsmasq não parece estar rodando. Verifique $DNSMASQ_LOG."
fi

# 4. NAT e Firewall (iptables)
# Não limpa as regras existentes (isso apagaria o ufw). As regras abaixo são
# inseridas no topo das cadeias, antes das do ufw, e somem no reboot.
echo "Configurando NAT e iptables..."

# Adiciona a regra apenas se ainda não existir (permite rodar o script de novo)
add_rule() {
    local table=$1 action=$2 chain=$3
    shift 3
    iptables -t "$table" -C "$chain" "$@" 2>/dev/null || iptables -t "$table" "$action" "$chain" "$@"
}

# Aceita tudo que chega dos drones na própria estação (DHCP, DNS, telemetria)
add_rule filter -I INPUT -i "$LAN_IF" -j ACCEPT
# Encaminha tráfego dos drones para a internet e as respostas de volta
add_rule filter -I FORWARD -i "$LAN_IF" -s "$LAN_NET" -j ACCEPT
add_rule filter -I FORWARD -o "$LAN_IF" -d "$LAN_NET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Masquerade (NAT) apenas do tráfego dos drones, saindo por qualquer interface
# exceto $LAN_IF (Wi-Fi ou USB, a que estiver ativa).
# O -s é essencial: sem ele o tráfego local via lo (ex.: DNS para 127.0.0.53)
# também seria mascarado e o systemd-resolved o descartaria, deixando a
# própria estação sem DNS.
add_rule nat -A POSTROUTING -s "$LAN_NET" ! -o "$LAN_IF" -j MASQUERADE

echo "=== Configuração Concluída ==="
echo "Status atual da $LAN_IF:"
ip addr show "$LAN_IF"
echo ""
echo "Saída para a internet (rota padrão):"
ip route show default || true
echo ""
echo "Regras de NAT:"
iptables -t nat -S POSTROUTING
echo ""
echo "Para reverter, reinicie o computador."
