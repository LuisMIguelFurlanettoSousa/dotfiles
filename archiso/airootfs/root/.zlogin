# Auto-executar o menu-live no login do root (apenas no tty1)
if [ "$(tty)" = "/dev/tty1" ]; then
    menu-live
fi
