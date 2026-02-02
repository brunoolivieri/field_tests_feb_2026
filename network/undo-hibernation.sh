#!/bin/bash
# undo-hibernation.sh
# Remove as configurações de hibernação aplicadas pelo hibernation-enabler.sh
# Autor: Antigravity Agent

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Script de Reversão de Hibernação (Ubuntu 24.04) ===${NC}"

# 1. Verificação de Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}ERRO: Este script precisa ser executado como root.${NC}"
   echo "Use: sudo ./undo-hibernation.sh"
   exit 1
fi

# Variáveis usadas no script original
SWAP_FILE="/swap.img"
GRUB_FILE="/etc/default/grub"
RESUME_FILE="/etc/initramfs-tools/conf.d/resume"

# 2. Remover arquivo de swap dedicado à hibernação
echo -e "\n${YELLOW}[1/4] Verificando arquivo de swap extra (${SWAP_FILE})...${NC}"
if [ -f "$SWAP_FILE" ]; then
    if swapon --show | grep -q "$SWAP_FILE"; then
        echo "Desativando swap ativo ($SWAP_FILE)..."
        swapoff "$SWAP_FILE"
    fi
    echo "Removendo arquivo $SWAP_FILE..."
    rm "$SWAP_FILE"
    echo "Arquivo removido."
else
    echo "Nenhum arquivo $SWAP_FILE encontrado. Nada a fazer."
fi

# 3. Limpar configurações do Initramfs
echo -e "\n${YELLOW}[2/4] Limpar configurações do Initramfs...${NC}"
if [ -f "$RESUME_FILE" ]; then
    echo "Removendo $RESUME_FILE..."
    rm "$RESUME_FILE"
    echo -e "Atualizando initramfs (pode demorar)..."
    update-initramfs -u
    echo "Initramfs atualizado."
else
    echo "Arquivo de resume ($RESUME_FILE) não encontrado. Nada a fazer."
fi

# 4. Limpar configurações do GRUB
echo -e "\n${YELLOW}[3/4] Limpando GRUB...${NC}"
CHANGES_NEEDED=false

if grep -q "resume=UUID=" "$GRUB_FILE" || grep -q "resume_offset=" "$GRUB_FILE"; then
    echo "Parâmetros de hibernação detectados no GRUB. Removendo..."
    
    # Backup
    cp "$GRUB_FILE" "${GRUB_FILE}.undo_bak_$(date +%s)"
    
    # Remove resume=UUID=... e resume_offset=... garantindo que não quebre as aspas finais
    # A regex [^ \"]* casa caracteres que não sejam espaço nem aspas duplas
    sed -i 's/ resume=UUID=[^ \"]*//g' "$GRUB_FILE"
    sed -i 's/ resume_offset=[^ \"]*//g' "$GRUB_FILE"
    
    CHANGES_NEEDED=true
else
    echo "GRUB limpo (sem parâmetros de hibernação)."
fi

if [ "$CHANGES_NEEDED" = true ]; then
    echo "Atualizando GRUB..."
    update-grub
    echo "GRUB atualizado."
fi

echo -e "\n${GREEN}=== Reversão concluída com sucesso! ===${NC}"
echo "Seu sistema está reconfigurado."
echo "Por favor, reinicie a máquina para garantir que todas as alterações (Kernel/Initramfs) sejam aplicadas."
