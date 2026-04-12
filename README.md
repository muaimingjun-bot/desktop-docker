# GNOME Desktop in Docker via noVNC

基于 [jockerdragon/docker-systemd](https://hub.docker.com/r/jockerdragon/docker-systemd) 的完整 Ubuntu GNOME 桌面容器，通过 noVNC 在浏览器中访问。

## 特性

- 完整 Ubuntu GNOME 桌面（ubuntu-desktop）
- 浏览器访问（noVNC，端口 6080）
- VNC 直连（端口 5901）
- systemd 作为 PID 1，保证 GNOME session 正常运行

## 快速开始

```bash
# 构建
docker build -t gnome-novnc .

# 运行
docker run -d \
  --privileged \
  --name gnome-desktop \
  -p 6080:6080 \
  -p 5901:5901 \
  -e VNC_PASSWORD=yourpassword \
  gnome-novnc
```

浏览器打开 `http://localhost:6080`，输入密码即可。

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `VNC_PASSWORD` | `password` | VNC/noVNC 登录密码 |
| `VNC_RESOLUTION` | `1920x1080` | 桌面分辨率 |
| `VNC_DEPTH` | `24` | 色深 |
| `VNC_PORT` | `5901` | VNC 端口 |
| `NOVNC_PORT` | `6080` | noVNC 端口 |

## 注意事项

- 必须使用 `--privileged` 运行，systemd 需要此权限
- 首次启动 GNOME 需要约 10-15 秒
