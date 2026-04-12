#!/bin/bash
set -e

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

# Start full Ubuntu GNOME session via dbus-run-session
echo "[desktop] Starting Ubuntu GNOME session"
su - vnc -s /bin/bash -c "
    export DISPLAY=:1
    export XDG_SESSION_TYPE=x11
    export XDG_CURRENT_DESKTOP=ubuntu:GNOME
    export GNOME_SHELL_SESSION_MODE=ubuntu
    export XDG_RUNTIME_DIR=/run/user/${VNC_UID}
    export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
    export XDG_DATA_DIRS=/usr/share/ubuntu:/usr/share/gnome:/usr/local/share:/usr/share
    dbus-run-session -- gnome-session --session=ubuntu 2>/tmp/gnome-session.log &
" &

# Wait for gnome-shell
echo "[desktop] Waiting for gnome-shell..."
for i in $(seq 1 60); do
    if pgrep -x gnome-shell > /dev/null 2>&1; then
        echo "[desktop] gnome-shell running (${i}s)"
        sleep 5
        break
    fi
    sleep 1
done

if ! pgrep -x gnome-shell > /dev/null 2>&1; then
    echo "[desktop] gnome-shell failed to start, check /tmp/gnome-session.log"
    cat /tmp/gnome-session.log 2>/dev/null || true
fi

# Start x11vnc
echo "[desktop] Starting x11vnc on :${VNC_PORT}"
x11vnc -display :1 \
    -rfbport ${VNC_PORT} \
    -rfbauth /home/vnc/.vnc/passwd \
    -forever \
    -shared \
    -noxdamage \
    -bg \
    -o /var/log/x11vnc.log

# Start noVNC
echo "[desktop] Starting noVNC on :${NOVNC_PORT}"
exec websockify --web=/usr/share/novnc \
    --wrap-mode=ignore \
    ${NOVNC_PORT} \
    localhost:${VNC_PORT}
