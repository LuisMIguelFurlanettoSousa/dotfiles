#!/bin/bash
# Troca a janela ativa com a vizinha na direção indicada.
# Sai do fullscreen de ambas as janelas antes de trocar.

direction="$1"

# Sai do fullscreen da janela ativa (se estiver)
active_fs=$(hyprctl activewindow -j | jq '.fullscreen')
[ "$active_fs" != "0" ] && hyprctl dispatch fullscreen 0

# Move o foco para a direção do swap para verificar a janela destino
hyprctl dispatch movefocus "$direction"

# Sai do fullscreen da janela destino (se estiver)
target_fs=$(hyprctl activewindow -j | jq '.fullscreen')
[ "$target_fs" != "0" ] && hyprctl dispatch fullscreen 0

# Volta o foco para a janela original
case "$direction" in
  l) hyprctl dispatch movefocus r ;;
  r) hyprctl dispatch movefocus l ;;
  u) hyprctl dispatch movefocus d ;;
  d) hyprctl dispatch movefocus u ;;
esac

# Agora executa o swap
hyprctl dispatch swapwindow "$direction"
