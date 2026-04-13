FROM jockerdragon/docker-systemd:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive \
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    VNC_RESOLUTION=1920x1080 \
    VNC_DEPTH=24 \
    VNC_PASSWORD=password \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai

# Install ubuntu-desktop then remove unwanted packages
RUN apt-get update && apt-get install -y \
    ubuntu-desktop \
    language-pack-zh-hans \
    language-pack-gnome-zh-hans \
    fonts-noto-cjk \
    ibus \
    ibus-pinyin \
    tzdata \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    python3 \
    sudo \
    net-tools \
    curl \
    git \
    vim \
    firefox \
    xdotool \
    xclip \
    && apt-get remove -y --purge \
        libreoffice* \
        thunderbird \
        rhythmbox \
        totem \
        shotwell \
        transmission-gtk \
        remmina \
        gnome-games \
        aisleriot \
        gnome-mahjongg \
        gnome-mines \
        gnome-sudoku \
        cheese \
        simple-scan \
        gnome-calendar \
        gnome-clocks \
        gnome-weather \
        gnome-maps \
        gnome-contacts \
        gnome-music \
        gnome-photos \
        deja-dup \
        brltty \
        orca \
        hplip \
        printer-driver-* \
        foomatic-db* \
        openprinting-ppds \
        cups-browsed \
        sane-utils \
        usb-creator-gtk \
        usb-modeswitch \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set timezone and locale
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    locale-gen zh_CN.UTF-8 && \
    update-locale LANG=zh_CN.UTF-8

# Create vnc user
RUN useradd -m -s /bin/bash vnc && \
    echo "vnc:vnc" | chpasswd && \
    usermod -aG sudo vnc && \
    echo "vnc ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# noVNC index + self-signed cert for clipboard API (requires HTTPS)
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html && \
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
        -keyout /etc/novnc-key.pem \
        -out /etc/novnc-cert.pem \
        -subj "/CN=novnc"

# install chrome 
RUN  wget  https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo apt install ./google-chrome-stable_current_amd64.deb && rm ./google-chrome-stable_current_amd64.deb

# Disable GNOME screensaver/lock/power via dconf system-wide defaults
RUN mkdir -p /etc/dconf/db/local.d /etc/dconf/profile && \
    printf '[org/gnome/desktop/screensaver]\nlock-enabled=false\nidle-activation-enabled=false\n\n[org/gnome/desktop/session]\nidle-delay=uint32 0\n\n[org/gnome/settings-daemon/plugins/power]\nsleep-inactive-ac-type='"'"'nothing'"'"'\nsleep-inactive-battery-type='"'"'nothing'"'"'\nidle-dim=false\npower-button-action='"'"'nothing'"'"'\n\n[org/gnome/desktop/input-sources]\nsources=[('"'"'ibus'"'"', '"'"'pinyin'"'"'), ('"'"'xkb'"'"', '"'"'us'"'"')]\n' \
        > /etc/dconf/db/local.d/00-nodim && \
    printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user && \
    dconf update 2>/dev/null || true

COPY start-desktop.sh /usr/local/bin/start-desktop.sh
RUN chmod +x /usr/local/bin/start-desktop.sh

RUN printf '[Unit]\nDescription=VNC+noVNC Desktop Service\nAfter=multi-user.target dbus.service\n\n[Service]\nType=simple\nEnvironmentFile=-/etc/desktop-env\nExecStart=/usr/local/bin/start-desktop.sh\nRestart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n' \
    > /etc/systemd/system/desktop-vnc.service && \
    systemctl enable desktop-vnc.service 2>/dev/null || true

EXPOSE ${VNC_PORT} ${NOVNC_PORT}

CMD ["/sbin/init"]
