# Ghostty、kitty 和 Kwi 试用安装

2026-11-23，`tuf3`，KDE Plasma Wayland。三个程序都装在当前用户范围，保留已有的 Konsole。

- Ghostty `1.4.0` 和 kitty `0.50.0` 使用锁定 Nixpkgs 的预构建包，装入当前用户 Nix profile。Ghostty 的桌面入口为 `com.mitchellh.ghostty.desktop`，kitty 为 `kitty.desktop`。在隔离的 KWin Wayland 会话分别打开终端，让两个程序通过其命令入口启动 Bash 并写入测试文件，两个文件都成功生成。 [Ghostty](https://github.com/ghostty-org/ghostty) · [kitty](https://github.com/kovidgoyal/kitty)
- 锁定 Nixpkgs 里没有 Kwi，使用 Flathub 的 `org.kde.kwi` 稳定版 `0.1.0`，运行环境 `org.kde.Platform/x86_64/6.11`。Flatpak 命令也通过当前用户 Nix profile 安装。首次 `org.freedesktop.Flatpak` D-Bus 激活报 `unknown unit`，因为登录会话找不到 `flatpak-session-helper.service`。把 Nix 包里的用户服务链接到 `~/.config/systemd/user/flatpak-session-helper.service` 并重载后，`flatpak-spawn --host` 成功。随后实际启动 Kwi 窗口并执行宿主机 Bash，测试文件成功写入。 [Kwi 官方发布包](https://flathub.org/en/apps/org.kde.kwi)
- 当前 KDE 登录环境的 `XDG_DATA_DIRS` 未含 Flatpak 用户导出目录。链接 Kwi 的官方导出 `.desktop` 与 SVG 图标到用户应用和图标目录。按 KRunner 服务的实际环境重新运行 `kbuildsycoca6 --noincremental`，缓存中核实有 Ghostty、kitty 和 Kwi 的三个桌面入口。

## 卸载 kitty 和 Kwi

- 按用户要求，执行 `nix profile remove kitty` 和 `flatpak uninstall --user org.kde.kwi`。确认没有其他用户级 Flatpak 应用后，用 `flatpak uninstall --user --unused` 清理了 Kwi 使用的闲置运行库，并注销手动创建的 Kwi 菜单与图标链接。卸载时 Flatpak 覆盖只读的 `hicolor/index.theme` 报权限警告，退出码为 0，应用与运行库均已卸载。
- 在 KRunner 的实际环境重建 `ksycoca`，确认 `kitty.desktop` 和 `org.kde.kwi.desktop` 均已消失，`com.mitchellh.ghostty.desktop` 仍存在。用户配置及 Flatpak 工具保留。

## Ghostty 默认终端与 Starship

- Plasma 的默认终端写入用户的 `kdeglobals`，`[General]` 下 `TerminalApplication=ghostty`、`TerminalService=com.mitchellh.ghostty.desktop`。用户的 `~/.config/xdg-terminals.list` 首行也使用该桌面入口，供遵循 XDG 默认终端列表的程序读取。
- `~/.config/ghostty/config.ghostty` 使用 `command = /run/current-system/sw/bin/fish`。用 `ghostty +validate-config` 校验，在隔离的 KWin 会话正常打开 Ghostty 窗口，确认子进程为 fish。账户登录 Shell 继续使用 Bash，脚本沿用其 shebang 或显式调用的解释器。Ghostty 自带主题可用 `ghostty +list-themes` 查看，配置项为 `theme`。 [Ghostty 配置参考](https://ghostty.org/docs/config/reference)
- 配置中使用 `theme = Catppuccin Mocha`。本机内置该主题，`ghostty +validate-config` 校验通过，`ghostty +show-config` 返回该主题，通过 Ghostty 的 `reload-config` 动作重新加载。
- Home Manager 的 `programs.starship.enable = true` 已使 Bash、fish、Zsh 和 Nushell 的集成全部开启。验证 Bash 首次绘制的提示符、fish 的 `fish_prompt` 函数、Zsh 的 `STARSHIP_SHELL` 与提示符定义，以及 Nushell 在 PTY 内运行 `nu --execute` 时的 `STARSHIP_SHELL=nu` 和实际提示符。fish 在 `TERM=dumb` 时跳过 Starship 初始化，使用此环境探测会读到 Tide。Nushell 的非交互 `nu -c` 同样不能用于判断交互提示符。

## Ghostty 在 Plasma 任务栏显示白纸图标

- 复现时，运行中的 Plasma 任务栏显示白纸图标。KWin 报告 Ghostty 的 Wayland 应用 ID 是 `com.mitchellh.ghostty`，与官方桌面入口一致。使用 Plasma 会话环境新建 `TaskManager::TasksModel`，同一个窗口解析为 `applications:com.mitchellh.ghostty.desktop`，图标名为 `com.mitchellh.ghostty`，图标可用。 [Plasma 6.8.3 任务图标查询代码](https://github.com/KDE/plasma-workspace/blob/v6.8.3/libtaskmanager/waylandtasksmodel.cpp)
- 将用户 Nix profile 里的官方桌面入口和 256 像素 PNG 分别链接到 `~/.local/share/applications/com.mitchellh.ghostty.desktop` 和 `~/.local/share/icons/hicolor/256x256/apps/com.mitchellh.ghostty.png`。两条链接经过 `~/.nix-profile/share`，随 profile 更新。用 Plasma 的 `XDG_DATA_DIRS` 执行 `kbuildsycoca6 --noincremental` 后，已有面板仍显示白纸图标。
- 执行 `systemctl --user restart plasma-plasmashell.service` 后，在实际底栏确认显示了官方蓝色 Ghostty 图标。KWin 和 Ghostty 原有进程仍在。
