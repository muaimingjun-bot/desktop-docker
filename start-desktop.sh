#!/bin/bash

VNC_PORT=${VNC_PORT:-5901}
NOVNC_PORT=${NOVNC_PORT:-6080}
VNC_RESOLUTION=${VNC_RESOLUTION:-1920x1080}
VNC_DEPTH=${VNC_DEPTH:-24}
VNC_PASSWORD=${VNC_PASSWORD:-password}

# Set VNC password
mkdir -p /home/vnc/.vnc
x11vnc -storepasswd "${VNC_PASSWORD}" /home/vnc/.vnc/passwd
chmod 600 /home/vnc/.vnc/passwd
chown vnc:vnc /home/vnc/.vnc/passwd

# Clean stale locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# Start Xvfb
echo "[desktop] Starting Xvfb :1 (${VNC_RESOLUTION}x${VNC_DEPTH})"
Xvfb :1 -screen 0 ${VNC_RESOLUTION}x${VNC_DEPTH} &
sleep 2

# Setup XDG_RUNTIME_DIR for vnc user
VNC_UID=$(id -u vnc)
mkdir -p /run/user/${VNC_UID}
chmod 700 /run/user/${VNC_UID}
chown vnc:vnc /run/user/${VNC_UID}

DBUS_SOCKET="/run/user/${VNC_UID}/bus"

# Start a persistent D-Bus session daemon for the vnc user (non-blocking)
echo "[desktop] Starting persistent D-Bus session daemon"
rm -f "${DBUS_SOCKET}"
su - vnc -s /bin/bash -c "
    export XDG_RUNTIME_DIR=/run/user/${VNC_UID}
    dbus-daemon --session --address=unix:path=${DBUS_SOCKET} --nofork &
    disown
" &
sleep 2

echo "[desktop] D-Bus socket: ${DBUS_SOCKET}"

# Start full Ubuntu GNOME session
echo "[desktop] Starting Ubuntu GNOME session"
su - vnc -s /bin/bash -c "
    export DISPLAY=:1
    export XDG_SESSION_TYPE=x11
    export XDG_CURRENT_DESKTOP=ubuntu:GNOME
    export GNOME_SHELL_SESSION_MODE=ubuntu
    export XDG_RUNTIME_DIR=/run/user/${VNC_UID}
    export DBUS_SESSION_BUS_ADDRESS=unix:path=${DBUS_SOCKET}
    export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
    export XDG_DATA_DIRS=/usr/share/ubuntu:/usr/share/gnome:/usr/local/share:/usr/share
    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_ALL=zh_CN.UTF-8
    export GTK_IM_MODULE=ibus
    export QT_IM_MODULE=ibus
    export XMODIFIERS=@im=ibus
    ibus-daemon -drx &
    gnome-session --session=ubuntu >> /tmp/gnome-session.log 2>&1 &
    disown
" &

# Wait for gnome-shell
echo "[desktop] Waiting for gnome-shell..."
for i in $(seq 1 60); do
    if pgrep -x gnome-shell > /dev/null 2>&1; then
        echo "[desktop] gnome-shell running (${i}s)"
        break
    fi
    sleep 1
done

if ! pgrep -x gnome-shell > /dev/null 2>&1; then
    echo "[desktop] gnome-shell failed to start, check /tmp/gnome-session.log"
    cat /tmp/gnome-session.log 2>/dev/null || true
fi

# Disable all GNOME power/lock/idle settings to prevent auto-logout
echo "[desktop] Disabling GNOME idle/lock/power settings"
sleep 3
su - vnc -s /bin/bash -c "
    export DISPLAY=:1
    export DBUS_SESSION_BUS_ADDRESS=unix:path=${DBUS_SOCKET}
    export XDG_RUNTIME_DIR=/run/user/${VNC_UID}

    gsettings set org.gnome.desktop.screensaver lock-enabled false
    gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
    gsettings set org.gnome.desktop.session idle-delay 0
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
    gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'

    echo '[desktop] GNOME power/lock settings disabled'
" >> /tmp/gsettings.log 2>&1 || true

# Start x11vnc
echo "[desktop] Starting x11vnc on :${VNC_PORT}"
x11vnc -display :1 \
    -rfbport ${VNC_PORT} \
    -rfbauth /home/vnc/.vnc/passwd \
    -forever \
    -shared \
    -noxdamage \
    -xkb \
    -bg \
    -o /var/log/x11vnc.log

# Start noVNC (HTTPS for clipboard API support)
echo "[desktop] Starting noVNC on :${NOVNC_PORT} (HTTPS)"
exec websockify --web=/usr/share/novnc \
    --wrap-mode=ignore \
    --cert=/etc/novnc-cert.pem \
    --key=/etc/novnc-key.pem \
    ${NOVNC_PORT} \
    localhost:${VNC_PORT}
