#!/bin/bash
# Navegação inteligente: se a janela ativa estiver em fullscreen,
# navega entre workspaces; caso contrário, move o foco entre janelas.

direction="$1"

fullscreen=$(hyprctl activewindow -j | jq -r '.fullscreen')

if [ "$fullscreen" = "true" ] || [ "$fullscreen" = "1" ] || [ "$fullscreen" = "2" ]; then
    case "$direction" in
        l) hyprctl dispatch workspace e-1 ;;
        r) hyprctl dispatch workspace e+1 ;;
        u) hyprctl dispatch movefocus u ;;
        d) hyprctl dispatch movefocus d ;;
    esac
else
    hyprctl dispatch movefocus "$direction"
fi
