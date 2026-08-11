#!/bin/bash

# Script para abrir o Slack apenas no horário de trabalho:
# Segunda a Sexta-feira (1 a 5), das 06:00 às 18:00

DAY="${TEST_DAY:-$(date +%u)}"                 # 1 = Segunda, 5 = Sexta, 6 = Sábado, 7 = Domingo
HOUR="${TEST_HOUR:-$((10#$(date +%H)))}"        # Hora atual (0 a 23)

# Verifica se é Segunda a Sexta e se está entre 06:00 e 17:59 (antes das 18:00)
if [ "$DAY" -ge 1 ] && [ "$DAY" -le 5 ] && [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then
    if ! pgrep -x "slack" > /dev/null && ! pgrep -f "/usr/bin/slack" > /dev/null; then
        echo "Dentro do horário de trabalho (Dia $DAY, ${HOUR}h). Abrindo o Slack..."
        /usr/bin/slack --disable-gpu-compositing --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime --enable-features=WebRTCPipeWireCapturer --enable-features=WaylandWindowDecorations --disable-features=WaylandFractionalScaleV1 -s >/dev/null 2>&1 &
    else
        echo "Slack já está aberto."
    fi
else
    echo "Fora do horário de trabalho (Dia $DAY, ${HOUR}h). O Slack não será aberto."
fi
