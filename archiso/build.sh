#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Build da ISO customizada — Arch Linux + Hyprland
# ============================================================
# Uso: sudo ./build.sh
# Saída: ~/iso-out/archlinux-hyprland-YYYY.MM.DD-x86_64.iso
#
# Funciona em:
#   - Arch Linux (usa archiso direto)
#   - Ubuntu/Debian/Fedora/qualquer distro (usa Docker)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

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
# Detectar ambiente e decidir: nativo (Arch) ou Docker
# ============================================================

if [ "$EUID" -ne 0 ]; then
    error "Execute como root: sudo ./build.sh"
fi

# Se NÃO estiver no Arch Linux, usar Docker
if [ ! -f /etc/arch-release ]; then
    info "Sistema detectado: $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "não-Arch")"
    info "Archiso requer Arch Linux. Usando Docker para buildar..."

    # Verificar se Docker está instalado
    if ! command -v docker &>/dev/null; then
        echo ""
        echo -e "${YELLOW}Docker não encontrado. Instale com:${NC}"
        echo -e "  ${BOLD}Ubuntu/Debian:${NC} sudo apt install docker.io"
        echo -e "  ${BOLD}Fedora:${NC}        sudo dnf install docker"
        echo ""
        error "Docker é necessário para buildar fora do Arch Linux."
    fi

    # Verificar se o daemon Docker está rodando
    if ! docker info &>/dev/null; then
        info "Iniciando Docker..."
        systemctl start docker 2>/dev/null || service docker start 2>/dev/null || {
            error "Não foi possível iniciar o Docker. Rode: sudo systemctl start docker"
        }
    fi

    # Criar diretório de saída
    OUT_DIR="${SUDO_HOME:-$HOME}/iso-out"
    mkdir -p "$OUT_DIR"

    info "Baixando imagem do Arch Linux (se necessário)..."
    docker pull archlinux:latest

    info "Iniciando build dentro do container Docker..."
    echo ""

    docker run --rm --privileged \
        -v "$REPO_DIR":/dotfiles:ro \
        -v "$OUT_DIR":/iso-out \
        archlinux:latest \
        /bin/bash -c '
            set -euo pipefail
            echo "=== Container Arch Linux iniciado ==="

            # Instalar dependências
            pacman -Sy --noconfirm archiso rsync &>/dev/null
            echo "[OK] archiso instalado no container."

            # Rodar o build internamente
            # (re-executar este script dentro do Arch, agora com archiso disponível)
            cp -r /dotfiles /tmp/dotfiles-build
            cd /tmp/dotfiles-build/archiso
            export HOME=/root
            mkdir -p /iso-out

            # Executar a parte nativa do build
            bash ./build-native.sh
        '

    # Ajustar permissões da ISO (Docker roda como root)
    REAL_USER="${SUDO_USER:-$(whoami)}"
    chown -R "$REAL_USER:$REAL_USER" "$OUT_DIR" 2>/dev/null || true

    ISO_FILE=$(ls -t "$OUT_DIR"/archlinux-hyprland-*.iso 2>/dev/null | head -1)
    if [ -z "$ISO_FILE" ]; then
        error "ISO não foi gerada. Verifique os erros acima."
    fi

    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ISO gerada com sucesso (via Docker)!        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ISO:      ${BLUE}$ISO_FILE${NC}"
    echo -e "  Tamanho:  ${BLUE}$ISO_SIZE${NC}"
    echo ""
    echo -e "${YELLOW}Para gravar no USB:${NC}"
    echo -e "  sudo dd bs=4M if=$ISO_FILE of=/dev/sdX conv=fsync oflag=direct status=progress"
    echo ""
    exit 0
fi

# ============================================================
# Modo nativo (Arch Linux) — verificar archiso
# ============================================================

if ! pacman -Qi archiso &>/dev/null; then
    info "archiso não encontrado. Instalando..."
    pacman -S --needed --noconfirm archiso || error "Falha ao instalar archiso."
    success "archiso instalado."
fi

info "Sistema detectado: Arch Linux (modo nativo)"

# Modo nativo — chamar build-native.sh diretamente
exec "$SCRIPT_DIR/build-native.sh"
