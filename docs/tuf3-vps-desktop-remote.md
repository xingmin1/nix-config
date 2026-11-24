# VPS 图形桌面远控方案

2026-11-24，目标是远程打开 VPS 的 Linux 图形桌面，在浏览器里使用 Claude。这个目标与在 VPS 终端里运行 Claude Code 不同。

## 会话与当前配置

- OMP 会话里确实出现过 VPS、固定出口和 Claude 浏览器使用的讨论。它们是群友经验和转述，不能作为远程桌面实现的验证依据。
- 当前 tuf3 已有 Herdr 的 VPS 反向 SSH 通道。它把笔记本本地 SSH 通过 VPS 暴露给 Herdr，适合终端会话和维护，不能提供 VPS 的图形桌面。
- 当前 UU Remote Linux 服务运行在 tuf3 上。它是本机的 Linux 被控端，不能自动成为 VPS 的远程桌面服务。

## 选择

- 这台 VPS 已有 XFCE、Xorg、xrdp 和 Google Chrome，之前验证过的方案是直接复用 xrdp。
- xrdp 只监听 VPS 的 `127.0.0.1:3389`。本机通过 SSH 本地转发连接到同一个端口，再由 RDP 客户端打开 XFCE 会话。这个路径不把 RDP 端口暴露到公网，也不依赖 VPS 的 GPU。
- Sunshine 和 Moonlight 适合有硬件视频编码器的 GPU 主机。当前 VPS 只有 Cirrus Logic GD 5446 虚拟 VGA，没有 `/dev/dri`，不适合这条路径。 [Sunshine 官方文档](https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2getting__started.html)
- UU Remote Linux 只有在希望使用 UU 官方手机或桌面客户端时才考虑部署到 VPS。项目对 KDE Wayland 的 Portal 后端仍标为实验性。 [UU Remote Linux 支持说明](https://github.com/VallierDev/uu-remote-linux)
- RustDesk 的 Linux headless 模式需要额外的虚拟显示配置。它曾在本轮排查中短时安装用于对照，随后已清理，避免与已验证的 xrdp 路径重复。 [RustDesk Linux 文档](https://rustdesk.com/docs/en/client/linux/)

## 当前状态

- VPS 系统是 Debian 13，桌面为 XFCE 4.20，显示后端为 Xorg，xrdp 和 xorgxrdp 服务均启用并运行。
- `/etc/xrdp/xrdp.ini` 的 `[Globals]` 端口是 `tcp://127.0.0.1:3389`。VPS 内部回环 RDP 握手返回合法的 X.224 Connection Confirm，公网 `3389` 连接被拒绝。
- 独立桌面账号是 `claudeweb`，没有 sudo 权限。`~/.xsession` 通过 `dbus-run-session -- xfce4-session` 启动 XFCE，桌面快捷方式直接调用官方 Chrome 打开 `https://claude.ai/`。
- 本机连接脚本是 `~/.local/bin/vps-remote-desktop`。它建立 `SSH -L 3389:127.0.0.1:3389` 隧道，然后打开 Remmina 配置 `~/.local/share/remmina/vps-claudeweb.remmina`。
- 本机的连接凭据保存在 `~/.local/share/vps-claudeweb-credentials`，权限为 `0600`，不写入仓库。
