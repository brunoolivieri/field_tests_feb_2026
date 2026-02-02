#!/bin/bash
# gs_maker_ephemeral.sh - Configura a máquina como roteador de forma NÃO persistente
# As configurações aplicadas por este script serão perdidas após o reboot.
# Autor: Antigravity Agent

set -e

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

# 2. Configurar eth0
echo "Configurando eth0 (192.168.1.1)..."

# Tenta desconectar a interface do NetworkManager na sessão atual para evitar conflitos
if command -v nmcli >/dev/null 2>&1; then
    echo "Desconectando eth0 do NetworkManager temporariamente..."
    nmcli device disconnect eth0 || true
fi

# Configuração manual da interface
ip link set eth0 down
ip addr flush dev eth0
ip addr add 192.168.1.1/24 dev eth0
ip link set eth0 up

# 3. Servidor DHCP (dnsmasq)
echo "Iniciando servidor DHCP (dnsmasq)..."
# Mata instância anterior se houver (para garantir que nossas opções sejam usadas)
pkill dnsmasq || true

# Verifica se dnsmasq está instalado
if ! command -v dnsmasq >/dev/null 2>&1; then
    echo "AVISO: dnsmasq não encontrado. Tentando instalar..."
    apt-get update && apt-get install -y dnsmasq
fi

# Inicia dnsmasq como daemon (processo em background), sem criar serviço systemd
# Configurações passadas via linha de comando
dnsmasq \
    --conf-file=/dev/null \
    --interface=eth0 \
    --listen-address=192.168.1.1 \
    --bind-interfaces \
    --except-interface=lo \
    --dhcp-range=192.168.1.150,192.168.1.200,12h \
    --dhcp-option=3,192.168.1.1 \
    --dhcp-option=6,8.8.8.8,1.1.1.1 \
    --server=8.8.8.8 \
    --server=1.1.1.1

# 4. DNS Local
# O script original alterava /etc/systemd/resolved.conf.
# Aqui vamos tentar definir o DNS para a interface de saída atual via resolvectl (systemd-resolved), se disponível.
DEF_IFACE=$(ip route show default | awk '{print $5}' | head -n1)
if [ -n "$DEF_IFACE" ] && command -v resolvectl >/dev/null 2>&1; then
    echo "Configurando DNS para interface de saída ($DEF_IFACE)..."
    resolvectl dns "$DEF_IFACE" 8.8.8.8 1.1.1.1 || true
else
    echo "Pulando configuração de DNS local (interface padrão ou resolvectl não encontrados)."
fi

# 5. NAT e Firewall (iptables)
echo "Configurando NAT e iptables..."

# Limpa regras atuais (apenas em memória)
iptables -F
iptables -t nat -F
iptables -X

# Define políticas permissivas
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Regra de Masquerade (NAT) para tráfego saindo por qualquer interface exceto eth0
iptables -t nat -A POSTROUTING ! -o eth0 -j MASQUERADE

echo "=== Configuração Concluída ==="
echo "Status atual da eth0:"
ip addr show eth0
echo ""
echo "Para reverter, reinicie o computador."
