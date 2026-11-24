# LocalSend 安装与联机检查

2026-11-23，`tuf3`，KDE Plasma Wayland。使用锁定 Nixpkgs 的 LocalSend `1.18.0` 预构建包，在主机配置里设 `programs.localsend.enable = true`。该模块安装 `localsend_app` 和 `LocalSend.desktop`，默认同时放行 TCP、UDP `53317`。TCP 承载文件传输，UDP 用于组播发现。KDE 的 `plasma-xdg-desktop-portal-kde.service` 已运行。 [LocalSend 协议](https://github.com/localsend/protocol/blob/main/README.md) · [固定版本的 NixOS 模块](https://github.com/NixOS/nixpkgs/blob/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55/nixos/modules/programs/localsend.nix)

- 通过 `LocalSend.desktop` 启动后，`ss -H -lnut 'sport = :53317'` 显示 TCP 与 UDP 均已监听，`ip maddr show dev wlp44s0` 显示 Wi‑Fi 已加入 `224.0.0.167` 组播。开启 Clash TUN 时普通 `ip route get` 对组播显示 `dev Meta`，但这一版 LocalSend 对每个接口的 UDP 套接字显式设置组播发送接口，因此该路由结果不能单独说明发现流量走错。 [组播套接字源码](https://github.com/localsend/localsend/blob/v1.18.0/packages/core/src/multicast/socket.rs#L104-L115)
- 在本机分别请求 `127.0.0.1` 和 Wi‑Fi 地址的 `https://<地址>:53317/api/localsend/v2/info`。裸 `curl -k` 返回 `tlsv13 alert certificate required`，用一次性自签名客户端证书重试 HTTP 请求成功，返回 `alias=英俊的芒果`、`version=2.2`。该测试确认收件服务和本机 Wi‑Fi 地址上的监听，未代用户从手机发送文件。
- 整机构建遇到 GitHub Release 元数据的 `narHash` 不一致。刷新了仍指向相同版本的 Just LSP、GenOffice、OfficeCLI 元数据。Sheprd 的 `latest` 已经前进到 `v20261123.1`，因此将校验清单 URL 改到已安装的 `v20261118.1` 标签；旧、新清单的 NAR 哈希一致。
- 第 44 代系统已通过 `nixos-rebuild switch --store-path` 激活，`nix flake check --no-update-lock-file` 通过。用 `iptables -C nixos-fw -p tcp --dport 53317 -j nixos-fw-accept` 和对应的 `udp` 命令确认实际规则。应用入口位于 `/run/current-system/sw/share/applications/LocalSend.desktop`。系统切换后再次通过本机 Wi‑Fi 地址验证了 `/info`。
