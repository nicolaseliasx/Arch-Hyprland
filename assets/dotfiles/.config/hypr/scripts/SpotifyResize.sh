#!/usr/bin/env bash
# SpotifyResize.sh — Resize Spotify to float 820x1100 when it opens in special workspace

apply_spotify_resize() {
    local addr="$1"
    # Usar hl.dispatch via hyprctl eval para focar, tornar float e redimensionar
    hyprctl eval "
local addr = \"${addr}\"
local f = io.open(\"/tmp/spotify_resize.log\", \"a\")

-- Focar o Spotify
pcall(function() hl.dispatch(\"focuswindow\", \"address:\" .. addr) end)

-- Togglefloating (para tornar floating se não estiver)
pcall(function() hl.dispatch(\"togglefloating\", \"\") end)

-- Resize para 820x1100
pcall(function() hl.dispatch(\"resizewindowpixel\", \"exact 820 1100,address:\" .. addr) end)

-- Mover para posição
pcall(function() hl.dispatch(\"movewindowpixel\", \"exact 10 30,address:\" .. addr) end)

f:write(\"Resized Spotify \" .. addr .. \"\\n\")
f:close()
" 2>/dev/null
}

# Escutar eventos do Hyprland via socat
HYPR_INSTANCE=$(ls /run/user/$(id -u)/hypr/ 2>/dev/null | head -1)
if [ -z "$HYPR_INSTANCE" ]; then
    exit 1
fi

SOCKET="/run/user/$(id -u)/hypr/${HYPR_INSTANCE}/.socket2.sock"
if [ ! -S "$SOCKET" ]; then
    # Hyprland 0.56 pode não ter .socket2 - usar polling leve
    while true; do
        sleep 2
        # Checar se Spotify está aberto e não floating
        addr=$(hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
try:
    for c in json.load(sys.stdin):
        if 'spotify' in c['class'].lower() and not c.get('floating', True):
            print(c['address'])
            break
except: pass
" 2>/dev/null)
        if [ -n "$addr" ]; then
            apply_spotify_resize "$addr"
        fi
    done
else
    # Usar socket de eventos
    socat - "UNIX-CONNECT:${SOCKET}" | while read -r line; do
        if echo "$line" | grep -q "openwindow"; then
            # Pequeno delay para a janela estar pronta
            sleep 0.5
            addr=$(hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
try:
    for c in json.load(sys.stdin):
        if 'spotify' in c['class'].lower() and not c.get('floating', True):
            print(c['address'])
            break
except: pass
" 2>/dev/null)
            if [ -n "$addr" ]; then
                apply_spotify_resize "$addr"
            fi
        fi
    done
fi
