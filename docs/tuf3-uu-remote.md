# tuf3 UU 远程开机自启

2026-11-24，UU Remote Linux `0.2.62` 已配置为用户图形会话启动时自动运行。

- 服务为 `uuremote-native.service`，执行 `uuremote-server`。
- Home Manager 同时将服务链接到 `xdg-desktop-autostart.target.wants` 和 `graphical-session.target.wants`，覆盖桌面登录自启路径。
- 当前检查结果为 `enabled`、`active (running)`，主进程为 `uuremote-server`，服务的 `PartOf` 为 `graphical-session.target`。
- 通过 `systemctl --user enable --now uuremote-native.service` 再次确认启用状态。服务日志显示设备状态已向 UU 服务同步。
