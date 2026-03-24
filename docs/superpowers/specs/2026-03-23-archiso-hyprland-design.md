# ISO Customizada Arch Linux + Hyprland

**Data:** 2026-03-23
**Status:** Aprovado
**Branch:** `feat/archiso-hyprland`

---

## Resumo

ISO customizada construída com Archiso (perfil `releng`, base ISO 2026.02.01, kernel 6.18.7) que boota num menu interativo em TTY, permite test drive do Hyprland, e instala o sistema completo no disco com um comando.

## Decisões de Design

| Decisão | Escolha | Motivo |
|---------|---------|--------|
| Particionamento | Menu: "Disco inteiro" ou "Manual" (cfdisk) | Flexibilidade para iniciantes e experientes |
| Bootloader | GRUB + os-prober | Cobre UEFI + BIOS + dual-boot com detecção automática de outros SOs |
| Pacotes AUR | Não incluídos na ISO | ISO enxuta; AUR instalado via install.sh + yay |
| Tela inicial | Menu TTY interativo | Guia o usuário sem confusão |
| Organização | Dois scripts separados | full-install.sh (base) + install.sh (pós) |
| Terminal da ISO live | foot (oficial) | ghostty é AUR, não disponível no live; foot é leve e Wayland-nativo |
| Filesystem | ext4 | Mais testado e estável; btrfs seria melhor para snapshots mas adiciona complexidade desnecessária para o escopo |
| Timezone/Locale | Hardcoded pt_BR / São Paulo | Público-alvo brasileiro; simplifica a instalação |
| Swap | Baseado na RAM | RAM <= 8G: swap = RAM. RAM > 8G: swap = 8G. Equilíbrio entre hibernação e espaço |

## Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                    PENDRIVE USB                         │
│                                                         │
│  ISO baseada no Arch 2026.02.01 (kernel 6.18.7)        │
│  + Hyprland + dotfiles + pacotes oficiais               │
│                                                         │
│  Boot → Menu TTY:                                       │
│    [1] Iniciar Hyprland (test drive)                    │
│    [2] Instalar no disco                                │
│    [3] Shell                                            │
│                                                         │
│  Instalação:                                            │
│    full-install.sh → particiona, pacstrap, bootloader   │
│      └── install.sh → Hyprland, dotfiles, stow          │
└─────────────────────────────────────────────────────────┘
```

## Estrutura de Arquivos

```
dotfiles/
├── archiso/                            # Tudo da ISO customizada
│   ├── build.sh                        # Script para buildar a ISO
│   ├── profiledef.sh                   # Metadados da ISO (nome, label, permissões)
│   ├── packages.x86_64                 # Pacotes oficiais (um por linha)
│   ├── pacman.conf                     # Config do pacman para build
│   └── airootfs/                       # Sistema de arquivos raiz (/ da ISO live)
│       ├── etc/
│       │   ├── hostname
│       │   ├── locale.gen
│       │   ├── locale.conf
│       │   ├── vconsole.conf
│       │   ├── skel/                   # Dotfiles para novos usuários
│       │   │   ├── .config/
│       │   │   │   ├── hypr/
│       │   │   │   ├── waybar/
│       │   │   │   ├── wofi/
│       │   │   │   ├── wlogout/
│       │   │   │   ├── foot/            # Terminal do live (fallback para ghostty)
│       │   │   │   └── nvim/
│       │   │   └── .zshrc
│       │   └── systemd/system/
│       │       └── getty@tty1.service.d/
│       │           └── autologin.conf
│       ├── root/
│       │   └── .zlogin                 # Chama menu-live no login do root
│       ├── opt/
│       │   └── dotfiles/               # Cópia do repo completo (para install.sh)
│       └── usr/local/bin/
│           ├── menu-live               # Menu interativo TTY
│           ├── instalar-sistema        # Wrapper amigável
│           └── full-install.sh         # Instalação base do Arch
├── install.sh                          # Pós-instalação (sem alterações)
└── ...
```

## Componentes

### 1. `archiso/build.sh`

Script que automatiza o build completo da ISO:

1. Verifica se `archiso` está instalado
2. Copia o perfil `releng` de `/usr/share/archiso/configs/releng/` para um diretório temporário
3. Aplica as customizações sobre o perfil copiado:
   - Habilita multilib no `pacman.conf` do build (necessário para lib32-*)
   - Appende pacotes extras ao `packages.x86_64`
   - Copia `airootfs/` (dotfiles, scripts, configs)
   - Atualiza `profiledef.sh` (nome, permissões)
4. Copia dotfiles do repo para `airootfs/etc/skel/.config/`
5. Copia o repo completo para `airootfs/opt/dotfiles/`
6. Roda `sudo mkarchiso -v`
7. Saída: `~/iso-out/archlinux-hyprland-YYYY.MM.DD-x86_64.iso`

Motivo da cópia do releng em tempo de build: manter o perfil base sempre atualizado com a versão do archiso instalada, sem duplicar arquivos no repositório.

### 2. `archiso/packages.x86_64`

Pacotes extras (apenas oficiais) a serem adicionados ao perfil releng:

```
# Hyprland core
hyprland
hyprlock
xdg-desktop-portal-hyprland
hyprsunset

# Barra, menu, logout
waybar
wofi
wlogout

# Terminal (para o live — ghostty é AUR, instalado depois)
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
```

### 3. `menu-live`

Menu interativo exibido no TTY após auto-login do root:

```
╔══════════════════════════════════════════════╗
║     Arch Linux + Hyprland — Live USB         ║
║                                              ║
║  [1] Iniciar Hyprland (test drive)           ║
║  [2] Instalar no disco                       ║
║  [3] Shell                                   ║
╚══════════════════════════════════════════════╝
```

- Opção 1: `exec Hyprland`
- Opção 2: chama `instalar-sistema`
- Opção 3: retorna ao shell (exit)
- Input inválido: repete o menu

### 4. `instalar-sistema`

Wrapper simples que exibe informações sobre a instalação e chama `full-install.sh` com confirmação do usuário.

### 5. `full-install.sh`

Instalação base completa do Arch Linux. Fluxo:

```
1.  Validar pré-requisitos
    ├── Verificar se está rodando do live USB (checar /run/archiso)
    ├── Verificar conexão com internet (curl archlinux.org)
    └── Detectar modo de boot: cat /sys/firmware/efi/fw_platform_size
        ├── 64 → UEFI
        └── erro → BIOS

2.  Configurar teclado
    └── loadkeys br-abnt2

3.  Selecionar disco
    ├── Listar discos disponíveis (lsblk --nodeps --noheadings -o NAME,SIZE,TYPE)
    ├── Filtrar apenas type=disk
    └── Usuário escolhe o disco alvo (menu numerado)

4.  Menu de particionamento
    ├── [1] "Usar disco inteiro" (automático)
    │   ├── Confirmação explícita: "TODOS os dados de /dev/sdX serão apagados"
    │   ├── Calcular swap: RAM <= 8G → swap = RAM. RAM > 8G → swap = 8G
    │   ├── UEFI: sgdisk → EFI (1G, type ef00) + Swap (calculado, type 8200) + Root (restante, type 8300)
    │   └── BIOS: sgdisk → BIOS boot (1M, type ef02) + Swap (calculado, type 8200) + Root (restante, type 8300)
    └── [2] "Particionar manualmente"
        ├── Abre cfdisk /dev/sdX
        └── Após cfdisk, menu de seleção de partições:
            ├── Listar partições do disco (lsblk -o NAME,SIZE,FSTYPE,PARTLABEL)
            ├── Usuário seleciona: "Qual partição para ROOT?" (menu numerado)
            ├── Usuário seleciona: "Qual partição para SWAP?" (menu numerado, ou "nenhuma")
            └── Se UEFI: "Qual partição para EFI?" (menu numerado)

5.  Formatar partições
    ├── Confirmação: "As seguintes partições serão formatadas: ..."
    ├── EFI: mkfs.fat -F 32 (se UEFI)
    ├── Swap: mkswap + swapon
    └── Root: mkfs.ext4

6.  Montar partições
    ├── mount root → /mnt
    └── mount --mkdir EFI → /mnt/boot (se UEFI)

7.  Configurar mirrors
    └── reflector --country Brazil --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

8.  Detectar CPU e instalar sistema base
    ├── Detectar microcode: lscpu | grep -q "GenuineIntel" → intel-ucode, senão → amd-ucode
    └── pacstrap -K /mnt base linux linux-firmware linux-headers \
            <microcode> networkmanager grub efibootmgr os-prober \
            git base-devel sudo

9.  Gerar fstab
    ├── genfstab -U /mnt >> /mnt/etc/fstab
    └── Validar: [ -s /mnt/etc/fstab ] (se vazio, erro fatal)

10. Perguntar dados do usuário (ANTES do chroot)
    ├── Hostname (default: "archlinux")
    ├── Nome do usuário
    └── Senha do usuário

11. Configurar via arch-chroot
    ├── Timezone: ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime && hwclock --systohc
    ├── Locale: descomentar pt_BR.UTF-8 + en_US.UTF-8 em /etc/locale.gen && locale-gen
    ├── echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
    ├── echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
    ├── echo "<hostname>" > /etc/hostname
    ├── passwd (senha do root)
    ├── useradd -m -G wheel -s /bin/zsh <usuário>
    ├── passwd <usuário>
    ├── Configurar sudo: descomentar %wheel ALL=(ALL:ALL) ALL em /etc/sudoers via sed
    ├── Habilitar serviços: systemctl enable NetworkManager bluetooth
    ├── GRUB:
    │   ├── UEFI: grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    │   └── BIOS: grub-install --target=i386-pc /dev/sdX
    ├── Habilitar os-prober: descomentar GRUB_DISABLE_OS_PROBER=false em /etc/default/grub
    ├── grub-mkconfig -o /boot/grub/grub.cfg
    ├── Copiar /opt/dotfiles → /home/<usuário>/dotfiles (chown para o usuário)
    └── Executar install.sh via: arch-chroot /mnt runuser -u <usuário> -- /home/<usuário>/dotfiles/install.sh
        (runuser troca para o usuário sem precisar de sudo/su configurado previamente,
         e o install.sh passa na validação EUID != 0)

12. Finalizar
    ├── Desmontar: umount -R /mnt
    ├── swapoff -a
    └── Mensagem: "Instalação completa! Remova o pendrive e reinicie: sudo reboot"
```

Nota sobre pacotes duplicados: `git` e `base-devel` aparecem tanto no pacstrap (passo 8) quanto no install.sh. Isso é intencional — o pacstrap garante que estão disponíveis no chroot para o install.sh rodar, e o `--needed` do install.sh evita reinstalação.

### 6. `install.sh`

Sem alterações. Continua funcionando como pós-instalação standalone para quem já tem Arch instalado.

## Segurança

- ISO baseada na 2026.02.01 (kernel 6.18.7, sem bugs ativos de archinstall/kernel)
- Confirmação obrigatória antes de particionar/formatar disco (dupla confirmação no modo automático)
- Detecção automática de UEFI vs BIOS para o GRUB
- Mesmas proteções do install.sh: trap de erros, log completo, retry com backoff
- O full-install.sh valida se está rodando do live USB (checa /run/archiso) antes de executar
- install.sh executado via `runuser -u <usuário>` no chroot (nunca como root, respeitando a validação EUID)
- Checksums SHA256 gerados automaticamente pelo build.sh junto com a ISO

## Limitações

- Pacotes AUR (ghostty, vscode, bibata-cursor, jetbrains-mono-nerd) instalados depois via install.sh + yay
- ISO terá ~2-3 GB (maior que a oficial de ~1.4 GB)
- Build da ISO requer Arch Linux com `archiso` instalado
- lib32-* requer multilib habilitado no pacman.conf do build (o build.sh habilita automaticamente)
- Terminal do live é `foot` (não ghostty). A config de Hyprland no live deve apontar para foot como terminal padrão. Após instalação completa (com yay + ghostty), o install.sh aplica os dotfiles finais com ghostty
- Timezone e locale hardcoded para pt_BR / America/Sao_Paulo (público-alvo brasileiro)
