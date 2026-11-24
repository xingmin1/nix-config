# Linux 微信聊天记录导入排查

2026-11-23，`tuf3`，原生微信 `4.1.13.26`。电脑端显示「暂无法导入，请保持手机和电脑在同一网络」。在提示出现后的一次 `ss -H -lntp` 查询中，微信进程仍监听 `0.0.0.0:8016`，稍后监听自动关闭。另一台机器的实测端口为 `8015`，所以每次排查应查微信实际绑定的端口。 [社区现场记录](https://miprota.cc/posts/wechat-chat-import-timeout/)

- 本机 Wi‑Fi 接口为 `wlp44s0`，当时地址为 `192.168.5.95/24`。Clash TUN 同时启用，`ip -4 route get 192.168.5.1` 仍显示该局域网经物理网卡直连。Nix 防火墙已启用，评估结果中 TCP 放行列表和端口范围均未包含 `8016`，实际的 `INPUT` 链跳入了 `nixos-fw`。
- 临时在 `nixos-fw` 首位添加 `-i wlp44s0 -s 192.168.5.0/24 -d 192.168.5.95/32 -p tcp --dport 8016 -m comment --comment wechat-import-temporary -j ACCEPT`。管理员执行 `iptables -C` 验证存在。`tuf3-wechat-import-expire.timer` 以相同参数在 30 分钟后删除这条规则，未将其写入 Nix 配置。
- 第一次用 `systemd-run --user` 打开需要本机认证的终端时，systemd 展开了内层 Bash 的 `${rule[@]}`，导致 iptables 接到空参数。给外层 `systemd-run` 添加 `--expand-environment=no` 后端口放行成功。第一次创建的空参数定时器也已清除。
- 重新从手机发起导出时，电脑实际监听改为 `0.0.0.0:8015`。在同一接口、源网段和目的地址临时放行 `8015`，用 `iptables -C` 验证，并通过 `tuf3-wechat-import-8015-expire.timer` 在 30 分钟后删除。只放行本机观察到的两个 TCP 端口。
- 14:00:45 再次导出时，`ss` 显示 `192.168.5.95:8015` 与同一 Wi‑Fi 网段的手机建立 `ESTAB`。`ss -ti` 随后显示连接已收到 `697144666` 字节，用户也确认电脑开始导入或已完成。该观察验证了传输已恢复，但没有检查微信内的最终导入条数。
