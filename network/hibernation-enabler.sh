#!/bin/bash

# Aborta o script se algum comando falhar
set -e

# Cores para logs
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Script de Configuração de Hibernação (Ubuntu 24.04) ===${NC}"

# 1. Verificação de Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script precisa ser rodado como root.${NC}"
   exit 1
fi

# 2. Definição de Variáveis
SWAP_FILE="/swap.img"
RAM_SIZE_GB=$(free -g | awk '/^Mem:/{print $2}')
# Define tamanho do swap como RAM + 2GB para segurança
SWAP_SIZE_GB=$((RAM_SIZE_GB + 2))

echo "RAM detectada: ${RAM_SIZE_GB}GB"
echo "Tamanho do Swap alvo: ${SWAP_SIZE_GB}GB"

# 3. Criação/Redimensionamento do Swap
if [ -f "$SWAP_FILE" ]; then
    echo "Desativando swap atual..."
    swapoff "$SWAP_FILE" || true # Continua mesmo se não estiver ativo
    rm "$SWAP_FILE"
fi

echo "Criando novo arquivo de swap (isso pode demorar um pouco)..."
# Usando dd para garantir alocação contígua (essencial para hibernação)
dd if=/dev/zero of="$SWAP_FILE" bs=1G count="$SWAP_SIZE_GB" status=progress

chmod 600 "$SWAP_FILE"
mkswap "$SWAP_FILE"
swapon "$SWAP_FILE"

echo -e "${GREEN}Swap criado e ativado com sucesso!${NC}"

# 4. Obter UUID e Offset
ROOT_UUID=$(findmnt / -n -o UUID)
# Obtém o offset físico da primeira extensão do arquivo
SWAP_OFFSET=$(sudo filefrag -v "$SWAP_FILE" | awk '$1=="0:" {print $4}' | tr -d .)

if [[ -z "$ROOT_UUID" || -z "$SWAP_OFFSET" ]]; then
    echo -e "${RED}Falha ao obter UUID ou Offset. Abortando.${NC}"
    exit 1
fi

echo "UUID Root: $ROOT_UUID"
echo "Swap Offset: $SWAP_OFFSET"

# 5. Configurar GRUB
GRUB_FILE="/etc/default/grub"
BACKUP_GRUB="${GRUB_FILE}.bak.$(date +%F_%T)"

echo "Fazendo backup do GRUB para $BACKUP_GRUB..."
cp "$GRUB_FILE" "$BACKUP_GRUB"

# Remove configurações de hibernação antigas para evitar duplicidade
sed -i 's/ resume=UUID=[^ ]*//g' "$GRUB_FILE"
sed -i 's/ resume_offset=[^ ]*//g' "$GRUB_FILE"

# Adiciona os novos parâmetros
# Procura a linha GRUB_CMDLINE_LINUX_DEFAULT e insere os parâmetros antes da última aspa
sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 resume=UUID=$ROOT_UUID resume_offset=$SWAP_OFFSET\"/" "$GRUB_FILE"

echo "Atualizando GRUB..."
update-grub

# 6. Configurar Initramfs
RESUME_FILE="/etc/initramfs-tools/conf.d/resume"
echo "Configurando $RESUME_FILE..."
echo "RESUME=UUID=$ROOT_UUID resume_offset=$SWAP_OFFSET" > "$RESUME_FILE"

echo "Atualizando Initramfs..."
update-initramfs -u

echo -e "${GREEN}=== Configuração concluída! ===${NC}"
echo "1. Se você usa Secure Boot, verifique se ele não bloqueia a hibernação na BIOS."
echo "2. Instale a extensão 'Hibernate Status Button' no GNOME para ter o botão no menu."
echo "3. Reinicie o computador para aplicar as mudanças."
echo "   Comando para testar após reiniciar: 'sudo systemctl hibernate'"