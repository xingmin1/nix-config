# Folio 与 Notes 的 NixOS 试用安装

2026-11-23 在 `tuf3`（KDE Plasma Wayland、x86_64）安装。此处的 Notes 指 nuttyartist 的 Qt 应用。 [Folio 26.01 发布](https://github.com/toolstack/Folio/releases/tag/26.01) · [Notes 2.3.1 发布](https://github.com/nuttyartist/notes/releases/tag/v2.3.1)

## 安装

- 当前 `flake.lock` 的 Nixpkgs 修订为 `04906337b6d53e8bb0eaf0470ae9f070a4d4eb55`。评估主机配置得到 `pkgs.folio.version = "26.01"`、`pkgs.notes.version = "2.3.1"`。预检查显示两个应用和 Folio 的 `libgee` 共三个路径可从缓存取得，实际下载 5.2 MiB，解包 15.4 MiB。
- 安装到当前用户 Nix profile，便于试用后按应用卸载。 [Folio 的 Nixpkgs 包](https://github.com/NixOS/nixpkgs/blob/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55/pkgs/by-name/fo/folio/package.nix) · [Notes 的 Nixpkgs 包](https://github.com/NixOS/nixpkgs/blob/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55/pkgs/by-name/no/notes/package.nix)

```bash
nixpkgs_ref=github:nixos/nixpkgs/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55
nix profile add "$nixpkgs_ref#folio" "$nixpkgs_ref#notes"
```

## 验证

- Folio 的桌面入口为 `com.toolstack.Folio.desktop`，终端命令为 `com.toolstack.Folio`，并附有同名 D-Bus 激活服务。Notes 的桌面入口为 `io.github.nuttyartist.notes.desktop`，终端命令为 `notes`。两者的图标均通过 `kiconfinder6` 确认为可读文件。
- 用正在运行的 Plasma 和 KRunner 的环境执行 `kbuildsycoca6 --noincremental`。重建的应用索引中确认包含上述两个桌面入口。
- 使用独立 D-Bus 会话、临时 XDG 数据目录和虚拟 KWin 显示器启动两个应用。通过 Wayland 协议日志确认每个程序建立顶层窗口，报告的应用 ID 与桌面入口一致，并提交了窗口画面。首轮在 Wayland socket 刚出现时查询 KWin 的 D-Bus 名称过早，报 `The name org.kde.KWin was not provided by any .service files`。改用各应用的 Wayland 窗口和缓冲区事件验证后，两者均通过。Notes 在测试配置目录生成了 `Awesomeness/notes.db`。

## Vicinae 没有显示新程序

- 安装后 KDE 索引已有两个入口，Vicinae 0.29.2 的 `vicinae cmd list --json` 仍只有安装前的 204 条命令。其服务进程的 `XDG_DATA_DIRS` 已包含 `~/.nix-profile/share`，无需补路径。
- 执行 `systemctl --user restart vicinae.service`，等 `vicinae ping` 成功后复查。命令列表增至 206 条，新增 `applications:com.toolstack.Folio`（Folio）和 `applications:io.github.nuttyartist.notes`（Notes）。

## 卸载 Notes

- 2026-11-23 按用户要求执行 `nix profile remove notes`，共移除一个包。Notes 的本地数据目录 `~/.config/Awesomeness` 保留。
- 用 Plasma 和 KRunner 的进程环境重建 KDE 应用索引，并重启 `vicinae.service`。核对 KDE 缓存和 `vicinae cmd list --json`，均已移除 Notes，Folio 入口仍存在。
