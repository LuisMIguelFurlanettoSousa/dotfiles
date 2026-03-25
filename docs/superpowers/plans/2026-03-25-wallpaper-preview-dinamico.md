# Preview Dinâmico no Seletor de Wallpaper — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o preview estático do wallpaper picker por uma janela `swayimg` flutuante que atualiza em tempo real conforme o usuário navega no Rofi.

**Architecture:** O script principal abre o `swayimg` apontando para um symlink temporário e lança o Rofi com `-on-selection-changed`. A cada mudança de seleção, o script de preview atualiza o symlink e envia `SIGUSR1` ao `swayimg`, que recarrega a imagem via Lua config.

**Tech Stack:** Bash, swayimg (Lua config), Rofi 2.0, Hyprland window rules

---

## Estrutura de Arquivos

| Ação | Arquivo | Responsabilidade |
|------|---------|-----------------|
| Criar | `hypr/.config/hypr/scripts/swayimg-picker.lua` | Config Lua do swayimg: bind SIGUSR1 → reload + esconde UI |
| Modificar | `hypr/.config/hypr/scripts/wallpaper-picker.sh` | Script principal: orquestra swayimg + rofi |
| Modificar | `hypr/.config/hypr/scripts/wallpaper-preview.sh` | Atualiza symlink e envia SIGUSR1 ao swayimg |
| Modificar | `rofi/.config/rofi/wallpaper-picker.rasi` | Remove imagebox, layout só com listbox |
| Modificar | `hypr/.config/hypr/conf/windowrules.conf` | Window rule para swayimg-picker flutuante |

---

### Task 1: Instalar swayimg

- [ ] **Step 1: Instalar o pacote**

```bash
sudo pacman -S --noconfirm swayimg
```

- [ ] **Step 2: Verificar instalação**

```bash
swayimg --version
```

Esperado: versão 5.0 ou superior

- [ ] **Step 3: Commit**

Nenhum commit necessário — é instalação de pacote do sistema.

---

### Task 2: Criar config Lua do swayimg para o picker

**Files:**
- Criar: `hypr/.config/hypr/scripts/swayimg-picker.lua`

- [ ] **Step 1: Criar o arquivo de configuração Lua**

```lua
-- Configuração do swayimg para o wallpaper picker
-- Recarrega a imagem ao receber SIGUSR1 (quando a seleção muda no Rofi)

-- Esconder texto informativo (nome do arquivo, resolução, etc.)
swayimg.viewer.set_text("")

-- Desabilitar keybindings padrão para evitar interação acidental
swayimg.viewer.bind_reset()

-- Bind: ao receber SIGUSR1, recarregar a imagem do disco
swayimg.viewer.on_signal("USR1", function()
    swayimg.viewer.reload()
    swayimg.viewer.reset()
end)
```

- [ ] **Step 2: Tornar acessível via stow**

O arquivo já está dentro da estrutura `hypr/.config/hypr/scripts/` que é gerenciada pelo stow. Verificar que o symlink existe:

```bash
cd ~/dotfiles && stow hypr
ls -la ~/.config/hypr/scripts/swayimg-picker.lua
```

Esperado: symlink apontando para `~/dotfiles/hypr/.config/hypr/scripts/swayimg-picker.lua`

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add hypr/.config/hypr/scripts/swayimg-picker.lua
git commit -m "feat: adicionar config Lua do swayimg para preview do wallpaper picker"
```

---

### Task 3: Adicionar window rule para o swayimg-picker

**Files:**
- Modificar: `hypr/.config/hypr/conf/windowrules.conf`

- [ ] **Step 1: Adicionar a window rule**

Adicionar ao final de `windowrules.conf`:

```conf
# Preview flutuante do wallpaper picker (swayimg)
windowrule {
  name = swayimg-picker
  match:class = ^(swayimg-picker)$

  float = on
  size = 500 500
  move = 25% 25%
  no_focus = on
  no_blur = on
  no_shadow = on
}
```

Notas:
- `match:class = ^(swayimg-picker)$` — casa com o `--class swayimg-picker` passado ao swayimg
- `float = on` — janela flutuante
- `size = 500 500` — tamanho fixo compatível com o Rofi (500px)
- `move = 25% 25%` — posiciona à esquerda do centro
- `no_focus = on` — impede que roube foco do Rofi

- [ ] **Step 2: Commit**

```bash
cd ~/dotfiles
git add hypr/.config/hypr/conf/windowrules.conf
git commit -m "feat: adicionar window rule para preview flutuante do swayimg-picker"
```

---

### Task 4: Reescrever o script de preview

**Files:**
- Modificar: `hypr/.config/hypr/scripts/wallpaper-preview.sh`

- [ ] **Step 1: Reescrever o script**

Conteúdo completo de `wallpaper-preview.sh`:

```bash
#!/bin/bash
# Atualiza o preview do swayimg quando a seleção muda no Rofi
# Recebe o nome do wallpaper selecionado e envia SIGUSR1 ao swayimg

WALLPAPER_DIR="$HOME/Pictures/wallpapers/walls"
PREVIEW_LINK="/tmp/wallpaper-picker-preview"
FILE="$1"

[ -z "$FILE" ] && exit 0

FULL_PATH="$WALLPAPER_DIR/$FILE"

[ ! -f "$FULL_PATH" ] && exit 1

# Atualiza o symlink temporário para o wallpaper selecionado
ln -sf "$FULL_PATH" "$PREVIEW_LINK"

# Envia SIGUSR1 ao swayimg para recarregar a imagem
pkill -USR1 -f "swayimg.*swayimg-picker"
```

- [ ] **Step 2: Verificar permissão de execução**

```bash
chmod +x ~/dotfiles/hypr/.config/hypr/scripts/wallpaper-preview.sh
```

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add hypr/.config/hypr/scripts/wallpaper-preview.sh
git commit -m "feat: reescrever preview para atualizar swayimg via SIGUSR1"
```

---

### Task 5: Simplificar o tema Rofi

**Files:**
- Modificar: `rofi/.config/rofi/wallpaper-picker.rasi`

- [ ] **Step 1: Remover imagebox e ajustar layout**

Conteúdo completo de `wallpaper-picker.rasi`:

```rasi
@theme "/dev/null"
@import "colors.rasi"

configuration {
    font: "JetBrainsMono Nerd Font 10";
    show-icons: true;
}

window {
    transparency:      "real";
    location:          center;
    anchor:            center;
    fullscreen:        false;
    width:             400px;
    height:            500px;
    border:            2px solid;
    border-color:      @outline-variant;
    border-radius:     15px;
    background-color:  @surface;
}

mainbox {
    enabled:           true;
    spacing:           10px;
    padding:           12px;
    background-color:  transparent;
    orientation:       vertical;
    children:          [ "inputbar", "listview" ];
}

inputbar {
    enabled:           true;
    spacing:           10px;
    padding:           12px;
    border-radius:     10px;
    background-color:  @surface-container;
    text-color:        @on-surface;
    children:          [ "textbox-prompt-colon", "entry" ];
}

textbox-prompt-colon {
    enabled:           true;
    expand:            false;
    str:               " ";
    background-color:  inherit;
    text-color:        inherit;
}

entry {
    enabled:           true;
    background-color:  inherit;
    text-color:        inherit;
    cursor:            text;
    placeholder:       "Buscar wallpaper...";
    placeholder-color: @outline;
}

listview {
    enabled:           true;
    columns:           1;
    lines:             8;
    cycle:             true;
    dynamic:           true;
    scrollbar:         false;
    layout:            vertical;
    fixed-height:      true;
    spacing:           5px;
    background-color:  transparent;
    text-color:        @on-surface;
}

element {
    enabled:           true;
    spacing:           10px;
    padding:           6px;
    border-radius:     8px;
    background-color:  transparent;
    text-color:        @on-surface;
    cursor:            pointer;
}

element selected.normal {
    background-color:  @primary-container;
    text-color:        @on-primary-container;
}

element-icon {
    background-color:  transparent;
    size:              36px;
    cursor:            inherit;
    border-radius:     4px;
}

element-text {
    background-color:  transparent;
    text-color:        inherit;
    cursor:            inherit;
    vertical-align:    0.5;
    horizontal-align:  0.0;
}
```

Mudanças vs original:
- `mainbox.children`: removido `"imagebox", "listbox"` → agora `"inputbar", "listview"` direto
- Removido `imagebox`, `dummy`, `listbox` (wrappers desnecessários)
- `window.width`: reduzido de 500px para 400px (sem painel esquerdo)

- [ ] **Step 2: Commit**

```bash
cd ~/dotfiles
git add rofi/.config/rofi/wallpaper-picker.rasi
git commit -m "refactor: simplificar tema rofi removendo imagebox estático"
```

---

### Task 6: Reescrever o script principal do picker

**Files:**
- Modificar: `hypr/.config/hypr/scripts/wallpaper-picker.sh`

- [ ] **Step 1: Reescrever o script**

Conteúdo completo de `wallpaper-picker.sh`:

```bash
#!/bin/bash
# Seletor de Wallpaper — Rofi + swayimg (preview dinâmico) + swww

WALLPAPER_DIR="$HOME/Pictures/wallpapers/walls"
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"
PREVIEW_LINK="/tmp/wallpaper-picker-preview"
PREVIEW_SCRIPT="$HOME/.config/hypr/scripts/wallpaper-preview.sh"
SWAYIMG_CONFIG="$HOME/.config/hypr/scripts/swayimg-picker.lua"

if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Picker" "Diretório $WALLPAPER_DIR não encontrado." -u critical
    exit 1
fi

cd "$WALLPAPER_DIR" || exit 1

# Lista wallpapers ordenados por data de modificação
WALLPAPERS=($(ls -t *.jpg *.png *.jpeg *.webp *.gif 2>/dev/null))

if [ ${#WALLPAPERS[@]} -eq 0 ]; then
    notify-send "Wallpaper Picker" "Nenhum wallpaper encontrado." -u critical
    exit 1
fi

# Cria symlink inicial apontando para o primeiro wallpaper da lista
FIRST_WALL="$WALLPAPER_DIR/${WALLPAPERS[0]}"
ln -sf "$FIRST_WALL" "$PREVIEW_LINK"

# Inicia swayimg em background com classe customizada para window rule
swayimg --class swayimg-picker -c "$SWAYIMG_CONFIG" "$PREVIEW_LINK" &
SWAYIMG_PID=$!

# Garante que o swayimg será fechado ao sair (seleção ou ESC)
cleanup() {
    kill "$SWAYIMG_PID" 2>/dev/null
    rm -f "$PREVIEW_LINK"
}
trap cleanup EXIT

# Pequena pausa para o swayimg abrir antes do Rofi
sleep 0.2

IFS=$'\n'

# Abre Rofi com on-selection-changed para atualizar o preview
SELECTED_WALL=$(for a in "${WALLPAPERS[@]}"; do
    echo -en "$a\0icon\x1f$WALLPAPER_DIR/$a\n"
done | rofi -dmenu -p "" \
    -theme ~/.config/rofi/wallpaper-picker.rasi \
    -on-selection-changed "$PREVIEW_SCRIPT {}")

[ -z "$SELECTED_WALL" ] && exit 0

SELECTED_PATH="$WALLPAPER_DIR/$SELECTED_WALL"

if [ ! -f "$SELECTED_PATH" ]; then
    notify-send "Wallpaper Picker" "Arquivo não encontrado: $SELECTED_PATH" -u critical
    exit 1
fi

swww img "$SELECTED_PATH" --transition-type grow --transition-fps 60 --transition-duration 2

mkdir -p "$(dirname "$SYMLINK_PATH")"
ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"

notify-send "Wallpaper" "Aplicado: $SELECTED_WALL" -t 3000
```

Mudanças vs original:
- Coleta wallpapers em array para reutilizar (primeiro item para preview inicial)
- Cria symlink temporário `/tmp/wallpaper-picker-preview` para o swayimg
- Inicia `swayimg` em background com `--class swayimg-picker` e config Lua customizada
- Adiciona `trap cleanup EXIT` para garantir limpeza
- Troca `awww` para `swww` (nome correto do daemon)
- Adiciona `-on-selection-changed` ao Rofi

- [ ] **Step 2: Verificar permissão de execução**

```bash
chmod +x ~/dotfiles/hypr/.config/hypr/scripts/wallpaper-picker.sh
```

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add hypr/.config/hypr/scripts/wallpaper-picker.sh
git commit -m "feat: reescrever wallpaper picker com preview dinâmico via swayimg"
```

---

### Task 7: Teste manual integrado

- [ ] **Step 1: Garantir que swww daemon está rodando**

```bash
pgrep swww-daemon || swww-daemon &
```

- [ ] **Step 2: Executar o wallpaper picker**

```bash
~/.config/hypr/scripts/wallpaper-picker.sh
```

Esperado:
1. Janela `swayimg` aparece flutuante mostrando o primeiro wallpaper
2. Rofi abre ao lado com a lista de wallpapers
3. Ao navegar com setas, o swayimg atualiza o preview em tempo real
4. Ao confirmar (Enter), o wallpaper é aplicado via swww
5. Ao cancelar (ESC), ambas as janelas fecham sem alterar wallpaper

- [ ] **Step 3: Testar cenários de borda**

- ESC sem selecionar → swayimg fecha, symlink temporário removido
- Diretório vazio → notificação de erro
- Navegar rápido → preview acompanha sem travar

- [ ] **Step 4: Ajustar posição da window rule se necessário**

Se a posição do swayimg não ficar alinhada com o Rofi, ajustar os valores `move` e `size` em `windowrules.conf`.

- [ ] **Step 5: Commit final (se houve ajustes)**

```bash
cd ~/dotfiles
git add -A
git commit -m "fix: ajustar posicionamento do preview do wallpaper picker"
```
