FROM jockerdragon/docker-systemd:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive \
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    VNC_RESOLUTION=1920x1080 \
    VNC_DEPTH=24 \
    VNC_PASSWORD=password

RUN apt-get update && apt-get install -y \
    ubuntu-desktop \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    python3 \
    sudo \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create vnc user
RUN useradd -m -s /bin/bash vnc && \
    echo "vnc:vnc" | chpasswd && \
    usermod -aG sudo vnc && \
    echo "vnc ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# noVNC index
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Setup script as a systemd service so it runs after dbus/systemd is ready
COPY start-desktop.sh /usr/local/bin/start-desktop.sh
RUN chmod +x /usr/local/bin/start-desktop.sh

RUN printf '[Unit]\nDescription=VNC+noVNC Desktop Service\nAfter=multi-user.target dbus.service\n\n[Service]\nType=simple\nEnvironmentFile=-/etc/desktop-env\nExecStart=/usr/local/bin/start-desktop.sh\nRestart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n' \
    > /etc/systemd/system/desktop-vnc.service && \
    systemctl enable desktop-vnc.service 2>/dev/null || true

EXPOSE ${VNC_PORT} ${NOVNC_PORT}

# systemd as PID 1 (required by base image)
CMD ["/sbin/init"]
