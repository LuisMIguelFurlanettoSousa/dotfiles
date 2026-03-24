# Archiso Hyprland — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar uma ISO customizada do Arch Linux com Hyprland pré-configurado usando Archiso, com menu interativo no boot e instalação automatizada no disco.

**Architecture:** ISO construída com Archiso (perfil releng). O `build.sh` copia o perfil releng, aplica customizações (pacotes, dotfiles, scripts) e gera a ISO. No boot, um menu TTY oferece test drive do Hyprland ou instalação. O `full-install.sh` faz a instalação base do Arch e chama o `install.sh` existente via `runuser` no chroot.

**Tech Stack:** Archiso, bash, mkarchiso, sgdisk, pacstrap, arch-chroot, GRUB

**Spec:** `docs/superpowers/specs/2026-03-23-archiso-hyprland-design.md`

---

## Mapa de Arquivos

| Arquivo | Ação | Responsabilidade |
|---------|------|------------------|
| `archiso/packages.x86_64` | Criar | Lista de pacotes extras para a ISO |
| `archiso/airootfs/usr/local/bin/menu-live` | Criar | Menu interativo TTY (opções 1/2/3) |
| `archiso/airootfs/usr/local/bin/instalar-sistema` | Criar | Wrapper amigável para full-install.sh |
| `archiso/airootfs/usr/local/bin/full-install.sh` | Criar | Instalação base completa do Arch |
| `archiso/airootfs/root/.zlogin` | Criar | Auto-executa menu-live no login |
| `archiso/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf` | Criar | Auto-login do root no TTY1 |
| `archiso/airootfs/etc/hostname` | Criar | Hostname da ISO live |
| `archiso/airootfs/etc/locale.conf` | Criar | Locale da ISO live |
| `archiso/airootfs/etc/vconsole.conf` | Criar | Keymap da ISO live |
| `archiso/airootfs/etc/locale.gen` | Criar | Locales a gerar na ISO |
| `archiso/build.sh` | Criar | Script de build da ISO |
| `install.sh` | Sem alterações | Pós-instalação existente |

---

### Task 1: Criar branch e estrutura de diretórios

**Files:**
- Criar: `archiso/` (estrutura de diretórios)

- [ ] **Step 1: Criar branch feat/archiso-hyprland**

```bash
git checkout -b feat/archiso-hyprland
```

- [ ] **Step 2: Criar estrutura de diretórios**

```bash
mkdir -p archiso/airootfs/etc/systemd/system/getty@tty1.service.d
mkdir -p archiso/airootfs/etc/skel/.config
mkdir -p archiso/airootfs/root
mkdir -p archiso/airootfs/usr/local/bin
mkdir -p archiso/airootfs/opt
```

- [ ] **Step 3: Commit**

```bash
git add archiso/
git commit -m "chore: estrutura de diretórios do archiso"
```

---

### Task 2: Criar packages.x86_64

**Files:**
- Criar: `archiso/packages.x86_64`

- [ ] **Step 1: Criar lista de pacotes extras**

```bash
cat > archiso/packages.x86_64 << 'PACOTES'
# ============================================================
# Pacotes extras para ISO Arch Linux + Hyprland
# ============================================================
# Estes pacotes são ADICIONADOS ao perfil releng durante o build.
# Apenas pacotes dos repositórios oficiais (sem AUR).
# ============================================================

# Hyprland core
hyprland
hyprlock
xdg-desktop-portal-hyprland
hyprsunset

# Barra, menu, logout
waybar
wofi
wlogout

# Terminal (para o live — ghostty é AUR, instalado depois pelo install.sh)
foot

# Utilitários Wayland
grim
slurp
wl-clipboard
swww

# Aparência
qt6ct
noto-fonts-emoji
materia-gtk-theme
papirus-icon-theme

# Áudio
pipewire
wireplumber
pipewire-pulse
pavucontrol

# Bluetooth
bluez
bluez-utils
blueman

# Rede
networkmanager
nm-connection-editor

# Gerenciador de arquivos
nemo

# Shell e ferramentas
zsh
eza
fzf
zoxide
tree
jq
neovim
stow

# Waybar dependência
pacman-contrib

# Polkit
polkit-gnome

# Instalação (necessário para full-install.sh)
grub
efibootmgr
os-prober
arch-install-scripts
reflector

# GPU (todos os drivers para compatibilidade universal)
mesa
vulkan-intel
lib32-mesa
lib32-vulkan-intel
vulkan-radeon
lib32-vulkan-radeon
nvidia-dkms
nvidia-utils
lib32-nvidia-utils
nvidia-settings
linux-headers
PACOTES
```

- [ ] **Step 2: Commit**

```bash
git add archiso/packages.x86_64
git commit -m "feat: lista de pacotes extras para a ISO (packages.x86_64)"
```

---

### Task 3: Criar configs do live (locale, hostname, autologin)

**Files:**
- Criar: `archiso/airootfs/etc/hostname`
- Criar: `archiso/airootfs/etc/locale.conf`
- Criar: `archiso/airootfs/etc/vconsole.conf`
- Criar: `archiso/airootfs/etc/locale.gen`
- Criar: `archiso/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf`

- [ ] **Step 1: Criar hostname**

```bash
echo "archlive" > archiso/airootfs/etc/hostname
```

- [ ] **Step 2: Criar locale.conf**

```bash
echo "LANG=pt_BR.UTF-8" > archiso/airootfs/etc/locale.conf
```

- [ ] **Step 3: Criar vconsole.conf**

```bash
echo "KEYMAP=br-abnt2" > archiso/airootfs/etc/vconsole.conf
```

- [ ] **Step 4: Criar locale.gen**

```bash
cat > archiso/airootfs/etc/locale.gen << 'EOF'
en_US.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
EOF
```

- [ ] **Step 5: Criar autologin no TTY1**

```bash
cat > archiso/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF
```

- [ ] **Step 6: Commit**

```bash
git add archiso/airootfs/etc/
git commit -m "feat: configurações do live (locale, hostname, autologin)"
```

---

### Task 4: Criar menu-live

**Files:**
- Criar: `archiso/airootfs/usr/local/bin/menu-live`

- [ ] **Step 1: Criar script menu-live**

O script exibe um menu com 3 opções. Usa cores ANSI e loop para input inválido. A opção 1 inicia o Hyprland, a 2 chama `instalar-sistema`, e a 3 retorna ao shell.

Conteúdo do arquivo `archiso/airootfs/usr/local/bin/menu-live`:

```bash
#!/usr/bin/env bash
# ============================================================
# Menu Live — Tela inicial da ISO Arch Linux + Hyprland
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_menu() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                              ║${NC}"
    echo -e "${CYAN}║     ${BOLD}Arch Linux + Hyprland${NC}${CYAN} — Live USB         ║${NC}"
    echo -e "${CYAN}║                                              ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║                                              ║${NC}"
    echo -e "${CYAN}║  ${GREEN}[1]${NC} Iniciar Hyprland (test drive)           ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BLUE}[2]${NC} Instalar no disco                       ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${YELLOW}[3]${NC} Shell                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║                                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

while true; do
    show_menu
    read -rp "$(echo -e "${BOLD}Escolha uma opção [1-3]:${NC} ")" opcao

    case "$opcao" in
        1)
            echo -e "${GREEN}Iniciando Hyprland...${NC}"
            exec Hyprland
            ;;
        2)
            exec instalar-sistema
            ;;
        3)
            echo -e "${YELLOW}Digite 'menu-live' para voltar ao menu.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida. Tente novamente.${NC}"
            sleep 1
            ;;
    esac
done
```

- [ ] **Step 2: Tornar executável**

```bash
chmod +x archiso/airootfs/usr/local/bin/menu-live
```

- [ ] **Step 3: Commit**

```bash
git add archiso/airootfs/usr/local/bin/menu-live
git commit -m "feat: menu interativo do live (test drive, instalar, shell)"
```

---

### Task 5: Criar instalar-sistema (wrapper)

**Files:**
- Criar: `archiso/airootfs/usr/local/bin/instalar-sistema`

- [ ] **Step 1: Criar script instalar-sistema**

Conteúdo do arquivo `archiso/airootfs/usr/local/bin/instalar-sistema`:

```bash
#!/usr/bin/env bash
# ============================================================
# Wrapper amigável para o full-install.sh
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                              ║${NC}"
echo -e "${CYAN}║  ${BOLD}Arch Linux + Hyprland${NC}${CYAN} — Instalador          ║${NC}"
echo -e "${CYAN}║                                              ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║                                              ║${NC}"
echo -e "${CYAN}║  Este instalador vai:                        ║${NC}"
echo -e "${CYAN}║                                              ║${NC}"
echo -e "${CYAN}║  ${GREEN}1.${NC} Particionar e formatar o disco           ${CYAN}║${NC}"
echo -e "${CYAN}║  ${GREEN}2.${NC} Instalar o Arch Linux base               ${CYAN}║${NC}"
echo -e "${CYAN}║  ${GREEN}3.${NC} Configurar GRUB, usuário e rede          ${CYAN}║${NC}"
echo -e "${CYAN}║  ${GREEN}4.${NC} Aplicar Hyprland + dotfiles + tema       ${CYAN}║${NC}"
echo -e "${CYAN}║                                              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}ATENÇÃO: Isso vai modificar o disco selecionado.${NC}"
echo -e "${YELLOW}Certifique-se de ter backup dos seus dados.${NC}"
echo ""
read -rp "$(echo -e "${BOLD}Continuar com a instalação? [s/N]:${NC} ")" resp

if [[ "$resp" =~ ^[sS]$ ]]; then
    exec /usr/local/bin/full-install.sh
else
    echo -e "${RED}Instalação cancelada.${NC}"
    echo ""
    echo -e "Digite ${BOLD}menu-live${NC} para voltar ao menu."
    exit 0
fi
```

- [ ] **Step 2: Tornar executável**

```bash
chmod +x archiso/airootfs/usr/local/bin/instalar-sistema
```

- [ ] **Step 3: Commit**

```bash
git add archiso/airootfs/usr/local/bin/instalar-sistema
git commit -m "feat: wrapper instalar-sistema com aviso e confirmação"
```

---

### Task 6: Criar full-install.sh — Parte 1 (validação, disco, particionamento)

**Files:**
- Criar: `archiso/airootfs/usr/local/bin/full-install.sh`

- [ ] **Step 1: Criar full-install.sh com cabeçalho, cores, trap, validação, seleção de disco e particionamento**

Conteúdo do arquivo `archiso/airootfs/usr/local/bin/full-install.sh` (parte 1 — funções auxiliares + passos 1 a 6 do spec):

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Full Install — Instalação base do Arch Linux
# ============================================================
# Chamado pelo instalar-sistema. Faz particionamento, pacstrap,
# chroot, GRUB e depois roda o install.sh dos dotfiles.
#
# Log: /tmp/full-install.log
# ============================================================

LOG_FILE="/tmp/full-install.log"

# ============================================================
# Cores
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERRO]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

# ============================================================
# Trap de erro
# ============================================================

trap_error() {
    local exit_code=$?
    local line_number=$1
    echo "" | tee -a "$LOG_FILE"
    echo -e "${RED}╔══════════════════════════════════════════╗${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}║  ERRO FATAL — instalação interrompida    ║${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}╚══════════════════════════════════════════╝${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}Linha:${NC} $line_number" | tee -a "$LOG_FILE"
    echo -e "${RED}Código de saída:${NC} $exit_code" | tee -a "$LOG_FILE"
    echo -e "${RED}Log:${NC} $LOG_FILE" | tee -a "$LOG_FILE"

    # Tentar desmontar caso tenha falhado no meio
    umount -R /mnt 2>/dev/null || true
    swapoff -a 2>/dev/null || true
}

trap 'trap_error ${LINENO}' ERR

echo "=== Instalação iniciada em $(date) ===" > "$LOG_FILE"

# ============================================================
# Variáveis globais (preenchidas durante a execução)
# ============================================================

BOOT_MODE=""         # uefi ou bios
TARGET_DISK=""       # /dev/sdX ou /dev/nvmeXnX
PART_EFI=""          # /dev/sdX1 (vazio se BIOS)
PART_SWAP=""         # /dev/sdX2
PART_ROOT=""         # /dev/sdX3
INSTALL_USER=""      # nome do usuário
INSTALL_HOSTNAME=""  # hostname
MICROCODE=""         # intel-ucode ou amd-ucode

# ============================================================
# 1. Validar pré-requisitos
# ============================================================

info "Validando pré-requisitos..."

# Verificar se está rodando do live USB
if [ ! -d /run/archiso ]; then
    error "Este script deve ser executado a partir da ISO live do Arch Linux."
fi

# Verificar conexão com internet
if ! curl -sf --max-time 10 "https://archlinux.org" > /dev/null 2>&1; then
    error "Sem conexão com a internet. Conecte-se via 'nmtui' ou 'iwctl' e tente novamente."
fi

# Detectar modo de boot
if [ -d /sys/firmware/efi/efivars ]; then
    BOOT_MODE="uefi"
    info "Modo de boot: UEFI"
else
    BOOT_MODE="bios"
    info "Modo de boot: BIOS/Legacy"
fi

# Detectar microcode
if lscpu | grep -qi "GenuineIntel"; then
    MICROCODE="intel-ucode"
else
    MICROCODE="amd-ucode"
fi
info "Microcode: $MICROCODE"

success "Pré-requisitos validados."

# ============================================================
# 2. Configurar teclado
# ============================================================

loadkeys br-abnt2
success "Teclado configurado (br-abnt2)."

# ============================================================
# 3. Selecionar disco
# ============================================================

info "Discos disponíveis:"
echo ""

# Listar discos (excluindo loop devices e o próprio USB)
mapfile -t DISKS < <(lsblk --nodeps --noheadings -o NAME,SIZE,TYPE | awk '$3=="disk" {print $1}')

if [ ${#DISKS[@]} -eq 0 ]; then
    error "Nenhum disco encontrado."
fi

for i in "${!DISKS[@]}"; do
    local_disk="${DISKS[$i]}"
    local_size=$(lsblk --nodeps --noheadings -o SIZE "/dev/$local_disk")
    local_model=$(lsblk --nodeps --noheadings -o MODEL "/dev/$local_disk" 2>/dev/null || echo "Desconhecido")
    echo -e "  ${GREEN}[$((i+1))]${NC} /dev/$local_disk — ${BOLD}$local_size${NC} — $local_model"
done

echo ""
read -rp "$(echo -e "${BOLD}Selecione o disco [1-${#DISKS[@]}]:${NC} ")" disk_choice

if ! [[ "$disk_choice" =~ ^[0-9]+$ ]] || [ "$disk_choice" -lt 1 ] || [ "$disk_choice" -gt ${#DISKS[@]} ]; then
    error "Opção inválida."
fi

TARGET_DISK="/dev/${DISKS[$((disk_choice-1))]}"
info "Disco selecionado: $TARGET_DISK"

# ============================================================
# 4. Menu de particionamento
# ============================================================

echo ""
echo -e "${BOLD}Como deseja particionar?${NC}"
echo -e "  ${GREEN}[1]${NC} Usar disco inteiro (automático)"
echo -e "  ${BLUE}[2]${NC} Particionar manualmente (abre cfdisk)"
echo ""
read -rp "$(echo -e "${BOLD}Opção [1-2]:${NC} ")" part_choice

case "$part_choice" in
    1)
        # ── Particionamento automático ──
        echo ""
        echo -e "${RED}${BOLD}ATENÇÃO: TODOS os dados de $TARGET_DISK serão APAGADOS!${NC}"
        read -rp "$(echo -e "${BOLD}Tem certeza? Digite 'SIM' para confirmar:${NC} ")" confirm
        if [ "$confirm" != "SIM" ]; then
            error "Particionamento cancelado pelo usuário."
        fi

        # Calcular swap baseado na RAM
        RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
        if [ "$RAM_GB" -le 8 ]; then
            SWAP_SIZE="${RAM_GB}G"
        else
            SWAP_SIZE="8G"
        fi
        info "Swap calculado: ${SWAP_SIZE} (RAM: ${RAM_GB}G)"

        # Limpar disco
        sgdisk --zap-all "$TARGET_DISK" >> "$LOG_FILE" 2>&1

        if [ "$BOOT_MODE" = "uefi" ]; then
            # UEFI: EFI (1G) + Swap + Root
            sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
            sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 -c 2:"Swap" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
            sgdisk -n 3:0:0 -t 3:8300 -c 3:"Root" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
        else
            # BIOS: BIOS boot (1M) + Swap + Root
            sgdisk -n 1:0:+1M -t 1:ef02 -c 1:"BIOS boot" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
            sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 -c 2:"Swap" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
            sgdisk -n 3:0:0 -t 3:8300 -c 3:"Root" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
        fi

        # Detectar nomes das partições (NVMe usa p1/p2/p3, SATA usa 1/2/3)
        if [[ "$TARGET_DISK" == *"nvme"* ]] || [[ "$TARGET_DISK" == *"mmcblk"* ]]; then
            PART_SUFFIX="p"
        else
            PART_SUFFIX=""
        fi

        if [ "$BOOT_MODE" = "uefi" ]; then
            PART_EFI="${TARGET_DISK}${PART_SUFFIX}1"
            PART_SWAP="${TARGET_DISK}${PART_SUFFIX}2"
            PART_ROOT="${TARGET_DISK}${PART_SUFFIX}3"
        else
            # BIOS: partição 1 é BIOS boot (não montar), swap é 2, root é 3
            PART_EFI=""
            PART_SWAP="${TARGET_DISK}${PART_SUFFIX}2"
            PART_ROOT="${TARGET_DISK}${PART_SUFFIX}3"
        fi

        success "Particionamento automático concluído."
        ;;

    2)
        # ── Particionamento manual ──
        info "Abrindo cfdisk para $TARGET_DISK..."
        cfdisk "$TARGET_DISK"

        # Menu de seleção de partições pós-cfdisk
        echo ""
        info "Partições detectadas:"
        echo ""
        mapfile -t PARTS < <(lsblk -ln -o NAME,SIZE,FSTYPE "$TARGET_DISK" | tail -n +2 | awk '{print $1}')

        if [ ${#PARTS[@]} -eq 0 ]; then
            error "Nenhuma partição encontrada em $TARGET_DISK. Rode novamente e crie as partições no cfdisk."
        fi

        for i in "${!PARTS[@]}"; do
            local_part="${PARTS[$i]}"
            local_info=$(lsblk -ln -o NAME,SIZE,FSTYPE "/dev/$local_part" | head -1)
            echo -e "  ${GREEN}[$((i+1))]${NC} /dev/$local_part — $local_info"
        done

        # Selecionar ROOT
        echo ""
        read -rp "$(echo -e "${BOLD}Qual partição para ROOT? [1-${#PARTS[@]}]:${NC} ")" root_choice
        PART_ROOT="/dev/${PARTS[$((root_choice-1))]}"

        # Selecionar SWAP
        echo ""
        read -rp "$(echo -e "${BOLD}Qual partição para SWAP? [1-${#PARTS[@]}, ou 0 para nenhuma]:${NC} ")" swap_choice
        if [ "$swap_choice" != "0" ]; then
            PART_SWAP="/dev/${PARTS[$((swap_choice-1))]}"
        else
            PART_SWAP=""
        fi

        # Selecionar EFI (se UEFI)
        if [ "$BOOT_MODE" = "uefi" ]; then
            echo ""
            read -rp "$(echo -e "${BOLD}Qual partição para EFI? [1-${#PARTS[@]}]:${NC} ")" efi_choice
            PART_EFI="/dev/${PARTS[$((efi_choice-1))]}"
        fi

        success "Partições selecionadas."
        ;;

    *)
        error "Opção inválida."
        ;;
esac

info "Root: $PART_ROOT"
[ -n "$PART_SWAP" ] && info "Swap: $PART_SWAP"
[ -n "$PART_EFI" ] && info "EFI:  $PART_EFI"

# ============================================================
# 5. Formatar partições
# ============================================================

echo ""
echo -e "${YELLOW}As seguintes partições serão formatadas:${NC}"
echo -e "  Root: ${BOLD}$PART_ROOT${NC} → ext4"
[ -n "$PART_SWAP" ] && echo -e "  Swap: ${BOLD}$PART_SWAP${NC} → swap"
[ -n "$PART_EFI" ] && echo -e "  EFI:  ${BOLD}$PART_EFI${NC} → FAT32"
echo ""
read -rp "$(echo -e "${BOLD}Confirmar formatação? [s/N]:${NC} ")" fmt_confirm
if [[ ! "$fmt_confirm" =~ ^[sS]$ ]]; then
    error "Formatação cancelada pelo usuário."
fi

info "Formatando partições..."

mkfs.ext4 -F "$PART_ROOT" >> "$LOG_FILE" 2>&1
success "Root formatado (ext4)."

if [ -n "$PART_SWAP" ]; then
    mkswap "$PART_SWAP" >> "$LOG_FILE" 2>&1
    swapon "$PART_SWAP" >> "$LOG_FILE" 2>&1
    success "Swap ativado."
fi

if [ -n "$PART_EFI" ]; then
    mkfs.fat -F 32 "$PART_EFI" >> "$LOG_FILE" 2>&1
    success "EFI formatado (FAT32)."
fi

# ============================================================
# 6. Montar partições
# ============================================================

info "Montando partições..."

mount "$PART_ROOT" /mnt
success "Root montado em /mnt."

if [ -n "$PART_EFI" ]; then
    mount --mkdir "$PART_EFI" /mnt/boot
    success "EFI montado em /mnt/boot."
fi
```

- [ ] **Step 2: Tornar executável**

```bash
chmod +x archiso/airootfs/usr/local/bin/full-install.sh
```

- [ ] **Step 3: Commit (parcial — script completo na Task 7)**

```bash
git add archiso/airootfs/usr/local/bin/full-install.sh
git commit -m "feat: full-install.sh parte 1 (validação, disco, particionamento)"
```

---

### Task 7: Criar full-install.sh — Parte 2 (mirrors, pacstrap, chroot, GRUB, install.sh)

**Files:**
- Modificar: `archiso/airootfs/usr/local/bin/full-install.sh` (adicionar ao final)

- [ ] **Step 1: Adicionar passos 7-12 ao full-install.sh**

Adicionar ao final do arquivo `archiso/airootfs/usr/local/bin/full-install.sh`:

```bash
# ============================================================
# 7. Configurar mirrors
# ============================================================

info "Configurando mirrors (Brasil)..."
reflector --country Brazil --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist >> "$LOG_FILE" 2>&1
success "Mirrors configurados."

# ============================================================
# 8. Instalar sistema base
# ============================================================

# zsh incluído no pacstrap porque useradd usa -s /bin/zsh (desvio documentado do spec)
info "Instalando sistema base (pacstrap)..."
pacstrap -K /mnt base linux linux-firmware linux-headers \
    "$MICROCODE" networkmanager grub efibootmgr os-prober \
    git base-devel sudo zsh >> "$LOG_FILE" 2>&1
success "Sistema base instalado."

# ============================================================
# 9. Gerar fstab
# ============================================================

info "Gerando fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

if [ ! -s /mnt/etc/fstab ]; then
    error "fstab está vazio. Algo deu errado na montagem."
fi

success "fstab gerado."

# ============================================================
# 10. Perguntar dados do usuário
# ============================================================

echo ""
echo -e "${BOLD}Configuração do sistema:${NC}"
echo ""

read -rp "$(echo -e "${BOLD}Hostname${NC} [archlinux]: ")" INSTALL_HOSTNAME
INSTALL_HOSTNAME="${INSTALL_HOSTNAME:-archlinux}"

read -rp "$(echo -e "${BOLD}Nome do usuário:${NC} ")" INSTALL_USER
while [ -z "$INSTALL_USER" ]; do
    echo -e "${RED}O nome do usuário não pode ser vazio.${NC}"
    read -rp "$(echo -e "${BOLD}Nome do usuário:${NC} ")" INSTALL_USER
done

echo -e "${BOLD}Senha do usuário ($INSTALL_USER):${NC}"
while true; do
    read -rsp "  Senha: " USER_PASS
    echo ""
    read -rsp "  Confirmar: " USER_PASS_CONFIRM
    echo ""
    if [ "$USER_PASS" = "$USER_PASS_CONFIRM" ] && [ -n "$USER_PASS" ]; then
        break
    fi
    echo -e "${RED}Senhas não conferem ou vazias. Tente novamente.${NC}"
done

echo -e "${BOLD}Senha do root:${NC}"
while true; do
    read -rsp "  Senha: " ROOT_PASS
    echo ""
    read -rsp "  Confirmar: " ROOT_PASS_CONFIRM
    echo ""
    if [ "$ROOT_PASS" = "$ROOT_PASS_CONFIRM" ] && [ -n "$ROOT_PASS" ]; then
        break
    fi
    echo -e "${RED}Senhas não conferem ou vazias. Tente novamente.${NC}"
done

# ============================================================
# 11. Configurar via arch-chroot
# ============================================================

info "Configurando o sistema via chroot..."

# Timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
arch-chroot /mnt hwclock --systohc

# Locale
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /mnt/etc/locale.gen
sed -i 's/^#pt_BR.UTF-8/pt_BR.UTF-8/' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen >> "$LOG_FILE" 2>&1
echo "LANG=pt_BR.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=br-abnt2" > /mnt/etc/vconsole.conf

# Hostname
echo "$INSTALL_HOSTNAME" > /mnt/etc/hostname

# Senha do root
echo "root:${ROOT_PASS}" | arch-chroot /mnt chpasswd

# Criar usuário
arch-chroot /mnt useradd -m -G wheel -s /bin/zsh "$INSTALL_USER"
echo "${INSTALL_USER}:${USER_PASS}" | arch-chroot /mnt chpasswd

# Configurar sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers

# Habilitar serviços
arch-chroot /mnt systemctl enable NetworkManager >> "$LOG_FILE" 2>&1
arch-chroot /mnt systemctl enable bluetooth >> "$LOG_FILE" 2>&1

success "Sistema configurado."

# ── GRUB ──

info "Instalando GRUB..."

if [ "$BOOT_MODE" = "uefi" ]; then
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB >> "$LOG_FILE" 2>&1
else
    arch-chroot /mnt grub-install --target=i386-pc "$TARGET_DISK" >> "$LOG_FILE" 2>&1
fi

# Habilitar os-prober
sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /mnt/etc/default/grub

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >> "$LOG_FILE" 2>&1
success "GRUB instalado e configurado."

# ── Dotfiles + install.sh ──

info "Copiando dotfiles e executando install.sh..."

# Copiar dotfiles do live para o sistema instalado
if [ -d /opt/dotfiles ]; then
    cp -r /opt/dotfiles "/mnt/home/${INSTALL_USER}/dotfiles"
    arch-chroot /mnt chown -R "${INSTALL_USER}:${INSTALL_USER}" "/home/${INSTALL_USER}/dotfiles"
    success "Dotfiles copiados para /home/${INSTALL_USER}/dotfiles."

    # Executar install.sh como o usuário (não como root)
    info "Executando install.sh (pós-instalação)..."
    arch-chroot /mnt runuser -u "$INSTALL_USER" -- /home/"$INSTALL_USER"/dotfiles/install.sh >> "$LOG_FILE" 2>&1 || {
        warn "install.sh retornou erro. Verifique o log: $LOG_FILE"
        warn "Você pode rodar manualmente após o reboot: cd ~/dotfiles && ./install.sh"
    }
else
    warn "/opt/dotfiles não encontrado. Pule a pós-instalação."
    warn "Após o reboot, clone os dotfiles e rode ./install.sh manualmente."
fi

# ============================================================
# 12. Finalizar
# ============================================================

info "Finalizando..."

umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

echo "" | tee -a "$LOG_FILE"
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}║                                              ║${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}║  Instalação concluída com sucesso!            ║${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}║                                              ║${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo -e "  Hostname:  ${BLUE}$INSTALL_HOSTNAME${NC}" | tee -a "$LOG_FILE"
echo -e "  Usuário:   ${BLUE}$INSTALL_USER${NC}" | tee -a "$LOG_FILE"
echo -e "  Boot:      ${BLUE}$BOOT_MODE${NC}" | tee -a "$LOG_FILE"
echo -e "  Microcode: ${BLUE}$MICROCODE${NC}" | tee -a "$LOG_FILE"
echo -e "  Log:       ${BLUE}$LOG_FILE${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo -e "${YELLOW}Remova o pendrive e reinicie:${NC}" | tee -a "$LOG_FILE"
echo -e "  ${BOLD}reboot${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
```

- [ ] **Step 2: Verificar sintaxe**

```bash
bash -n archiso/airootfs/usr/local/bin/full-install.sh
```

Esperado: nenhuma saída.

- [ ] **Step 3: Commit**

```bash
git add archiso/airootfs/usr/local/bin/full-install.sh
git commit -m "feat: full-install.sh parte 2 (mirrors, pacstrap, chroot, GRUB, dotfiles)"
```

---

### Task 8: Criar .zlogin (auto-executa menu no login)

**Files:**
- Criar: `archiso/airootfs/root/.zlogin`

- [ ] **Step 1: Criar .zlogin**

```bash
cat > archiso/airootfs/root/.zlogin << 'EOF'
# Auto-executar o menu-live no login do root (apenas no tty1)
if [ "$(tty)" = "/dev/tty1" ]; then
    menu-live
fi
EOF
```

- [ ] **Step 2: Commit**

```bash
git add archiso/airootfs/root/.zlogin
git commit -m "feat: .zlogin executa menu-live automaticamente no tty1"
```

---

### Task 9: Criar build.sh

**Files:**
- Criar: `archiso/build.sh`

- [ ] **Step 1: Criar build.sh**

Conteúdo do arquivo `archiso/build.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Build da ISO customizada — Arch Linux + Hyprland
# ============================================================
# Uso: sudo ./build.sh
# Saída: ~/iso-out/archlinux-hyprland-YYYY.MM.DD-x86_64.iso
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="/tmp/archiso-work"
OUT_DIR="$HOME/iso-out"
PROFILE_DIR="/tmp/archiso-profile"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[BUILD]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error()   { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# ============================================================
# 1. Verificar pré-requisitos
# ============================================================

if [ "$EUID" -ne 0 ]; then
    error "Execute como root: sudo ./build.sh"
fi

if ! pacman -Qi archiso &>/dev/null; then
    error "archiso não está instalado. Instale com: sudo pacman -S archiso"
fi

# ============================================================
# 2. Limpar builds anteriores
# ============================================================

info "Limpando builds anteriores..."
rm -rf "$WORK_DIR" "$PROFILE_DIR"
mkdir -p "$OUT_DIR"

# ============================================================
# 3. Copiar perfil releng
# ============================================================

info "Copiando perfil releng..."
cp -r /usr/share/archiso/configs/releng/ "$PROFILE_DIR"
success "Perfil releng copiado."

# ============================================================
# 4. Habilitar multilib no pacman.conf do build
# ============================================================

info "Habilitando multilib..."
sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' "$PROFILE_DIR/pacman.conf"
success "Multilib habilitado."

# ============================================================
# 5. Adicionar pacotes extras
# ============================================================

info "Adicionando pacotes extras..."
cat "$SCRIPT_DIR/packages.x86_64" >> "$PROFILE_DIR/packages.x86_64"

# Remover duplicatas mantendo a ordem
awk '!seen[$0]++ || /^#/ || /^$/' "$PROFILE_DIR/packages.x86_64" > "$PROFILE_DIR/packages.x86_64.tmp"
mv "$PROFILE_DIR/packages.x86_64.tmp" "$PROFILE_DIR/packages.x86_64"

success "$(wc -l < "$SCRIPT_DIR/packages.x86_64") pacotes extras adicionados."

# ============================================================
# 6. Copiar airootfs customizado
# ============================================================

info "Copiando configurações customizadas..."
cp -r "$SCRIPT_DIR/airootfs/"* "$PROFILE_DIR/airootfs/" 2>/dev/null || true

# Copiar dotfiles para /etc/skel
info "Copiando dotfiles para /etc/skel..."
SKEL_DIR="$PROFILE_DIR/airootfs/etc/skel"
mkdir -p "$SKEL_DIR/.config"

# Copiar módulos stow (sem a estrutura stow)
for module in hypr waybar wofi wlogout nvim; do
    if [ -d "$REPO_DIR/$module/.config/$module" ]; then
        cp -r "$REPO_DIR/$module/.config/$module" "$SKEL_DIR/.config/"
        success "  $module copiado para skel."
    fi
done

# GTK
if [ -d "$REPO_DIR/gtk-3.0/.config/gtk-3.0" ]; then
    cp -r "$REPO_DIR/gtk-3.0/.config/gtk-3.0" "$SKEL_DIR/.config/"
    success "  gtk-3.0 copiado para skel."
fi

# Ghostty config (mesmo sem o binário no live, prepara para pós-instalação)
if [ -d "$REPO_DIR/ghostty/.config/ghostty" ]; then
    cp -r "$REPO_DIR/ghostty/.config/ghostty" "$SKEL_DIR/.config/"
    success "  ghostty (config) copiado para skel."
fi

# ZSH
if [ -f "$REPO_DIR/zsh/.zshrc" ]; then
    cp "$REPO_DIR/zsh/.zshrc" "$SKEL_DIR/.zshrc"
    success "  .zshrc copiado para skel."
fi

# Wallpapers
if [ -f "$REPO_DIR/wallpapers/default.jpg" ]; then
    mkdir -p "$SKEL_DIR/Pictures/wallpapers/walls"
    cp "$REPO_DIR/wallpapers/default.jpg" "$SKEL_DIR/Pictures/wallpapers/walls/"
    success "  Wallpaper copiado para skel."
fi

# ── Fix terminal do live: substituir ghostty por foot no skel ──
# O programs.conf original usa $terminal = ghostty (AUR, não disponível no live).
# No skel, substituímos por foot para o test drive funcionar.
if [ -f "$SKEL_DIR/.config/hypr/conf/programs.conf" ]; then
    sed -i 's/\$terminal = ghostty/$terminal = foot/' "$SKEL_DIR/.config/hypr/conf/programs.conf"
    success "  Terminal do live substituído: ghostty → foot no programs.conf do skel."
fi

# ============================================================
# 7. Copiar repo completo para /opt/dotfiles
# ============================================================

info "Copiando repositório para /opt/dotfiles..."
OPT_DIR="$PROFILE_DIR/airootfs/opt/dotfiles"
mkdir -p "$OPT_DIR"

# Copiar tudo exceto .git, diretórios de build e ISOs anteriores
rsync -a --exclude='.git' --exclude='docs/superpowers' --exclude='iso-out' --exclude='*.iso' "$REPO_DIR/" "$OPT_DIR/"
success "Repositório copiado para /opt/dotfiles."

# ============================================================
# 8. Atualizar profiledef.sh
# ============================================================

info "Atualizando profiledef.sh..."

sed -i "s|^iso_name=.*|iso_name=\"archlinux-hyprland\"|" "$PROFILE_DIR/profiledef.sh"
sed -i "s|^iso_label=.*|iso_label=\"ARCH_HYPR_\$(date --date=\"@\${SOURCE_DATE_EPOCH:-\$(date +%s)}\" +%Y%m)\"|" "$PROFILE_DIR/profiledef.sh"
sed -i "s|^iso_publisher=.*|iso_publisher=\"Luis Miguel <https://github.com/LuisMIguelFurlanettoSousa>\"|" "$PROFILE_DIR/profiledef.sh"
sed -i "s|^iso_application=.*|iso_application=\"Arch Linux + Hyprland — Live/Install\"|" "$PROFILE_DIR/profiledef.sh"

# Adicionar permissões customizadas ao file_permissions
# Inserir antes do fecha-parênteses do array
sed -i '/^\s*\[\"\/etc\/gshadow\"\]/a\  ["/root/.zlogin"]="0:0:755"\n  ["/usr/local/bin/menu-live"]="0:0:755"\n  ["/usr/local/bin/instalar-sistema"]="0:0:755"\n  ["/usr/local/bin/full-install.sh"]="0:0:755"\n  ["/opt/dotfiles/install.sh"]="0:0:755"' "$PROFILE_DIR/profiledef.sh"

success "profiledef.sh atualizado."

# ============================================================
# 9. Build da ISO
# ============================================================

info "Iniciando build da ISO (isso pode levar 10-30 minutos)..."
echo ""

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

# ============================================================
# 10. Gerar checksum
# ============================================================

ISO_FILE=$(ls -t "$OUT_DIR"/archlinux-hyprland-*.iso 2>/dev/null | head -1)

if [ -z "$ISO_FILE" ]; then
    error "ISO não foi gerada. Verifique os erros acima."
fi

info "Gerando checksum SHA256..."
sha256sum "$ISO_FILE" > "${ISO_FILE}.sha256"

# ============================================================
# 11. Limpar
# ============================================================

info "Limpando arquivos temporários..."
rm -rf "$WORK_DIR" "$PROFILE_DIR"

# ============================================================
# Resumo
# ============================================================

ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ISO gerada com sucesso!                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ISO:      ${BLUE}$ISO_FILE${NC}"
echo -e "  Tamanho:  ${BLUE}$ISO_SIZE${NC}"
echo -e "  SHA256:   ${BLUE}${ISO_FILE}.sha256${NC}"
echo ""
echo -e "${YELLOW}Para testar com QEMU:${NC}"
echo -e "  run_archiso -u -i $ISO_FILE"
echo ""
echo -e "${YELLOW}Para gravar no USB:${NC}"
echo -e "  sudo dd bs=4M if=$ISO_FILE of=/dev/sdX conv=fsync oflag=direct status=progress"
echo ""
```

- [ ] **Step 2: Tornar executável**

```bash
chmod +x archiso/build.sh
```

- [ ] **Step 3: Verificar sintaxe**

```bash
bash -n archiso/build.sh
```

Esperado: nenhuma saída.

- [ ] **Step 4: Commit**

```bash
git add archiso/build.sh
git commit -m "feat: build.sh — script de build da ISO customizada"
```

---

### Task 10: Atualizar .gitignore

**Files:**
- Modificar: `.gitignore`

- [ ] **Step 1: Adicionar entradas do archiso ao .gitignore**

Adicionar ao final de `.gitignore`:

```
# Archiso build artifacts
iso-out/
*.iso
*.sha256
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: adicionar artefatos do archiso ao .gitignore"
```

---

### Task 11: Commit do spec e push da branch

**Files:**
- Commitar: `docs/superpowers/specs/2026-03-23-archiso-hyprland-design.md`
- Commitar: `docs/superpowers/plans/2026-03-23-archiso-hyprland.md`

- [ ] **Step 1: Commitar spec e plano**

```bash
git add docs/
git commit -m "docs: spec e plano de implementação do archiso-hyprland"
```

- [ ] **Step 2: Push da branch**

```bash
git push -u origin feat/archiso-hyprland
```
