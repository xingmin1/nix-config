# Vicinae 安装和拼音别名

2026-11-23，`tuf3`。锁定的 Nixpkgs 提供 Vicinae `0.29.2`。`nix build --dry-run '.#nixosConfigurations.tuf3.pkgs.vicinae'` 显示需要下载三个预构建路径，最终从交大 Nix 镜像获取包，无需构建源码或添加新软件源。用 Home Manager 的 `programs.vicinae` 安装软件包，并管理自动启动的用户服务。KDE 应用菜单的 `vicinae.desktop` 调用 `vicinae open` 打开已运行的启动器。 [NixOS 安装文档](https://docs.vicinae.com/nixos) · [KDE 快速入门](https://docs.vicinae.com/quickstart/kde)

- 从本机可见的 `.desktop` 文件和测试会话的 `vicinae cmd list --json` 交叉核对入口 ID。36 个应用使用 `providers.applications.entrypoints.<id>.alias`，KDE 输入法面板使用 `providers.kde-settings.entrypoints.kcm_fcitx5.alias`。系统设置只使用实际被索引的 `systemsettings` 入口。最终配置的 37 个 ID 在命令列表中都存在。Home Manager 通过 `mutableSettings` 生成 `home-manager.json` 并让服务加载，Vicinae 的其他图形设置仍可写入自己的 `settings.json`。 [应用 ID 生成规则](https://github.com/vicinaehq/vicinae/blob/v0.29.2/src/server/src/root-search/apps/app-root-provider.cpp)
- 用隔离的 KWin Wayland 会话对照同一版 Vicinae。将 WPS 表格别名设为 `biaoge` 时，输入 `biao ge` 未命中。将别名改为 `biao ge` 后，`biaoge` 和 `biao ge` 均命中。同样验证了 `tengxunhuiyi` 与 `teng xun hui yi` 命中腾讯会议。最终按音节存储，实测 `weixin`、`wei xin`、`wx` 能找到微信，`wenjianguanliqi` 能找到 Dolphin，`shu ru fa pei zhi` 能找到 KDE 输入法面板。首字母是模糊搜索，可以同时匹配其他程序。测试统一用 `vicinae open --query <拼音>` 打开真实界面并检查搜索结果。
- 整机构建和 `nix flake check` 均通过。为解决发布元数据的 `narHash` 过期，只刷新了仍指向已安装版本的 Just LSP、GenOffice、OfficeCLI 和 UU Remote Linux 元数据。因系统激活等待认证，实际使用用户 Nix profile 安装包，并将构建产物中的别名配置、系统服务及菜单入口链接至用户目录。`~/.local/state/vicinae/installation` 是该 Home Manager 输出的间接 GC 根。确认服务 `enabled`、`active`，`vicinae ping` 成功，真实会话中 37 个 ID 全部可用，且能通过 `.desktop` 入口打开窗口。整机系统代未切换。

## KDE 全局快捷键和 KRunner

- `Meta+Space` 即 Win+空格。KGlobalAccel 查询组合键编码 `268435488` 时没有登记。沿用 KDE 菜单编辑器的做法，将能执行 `vicinae open` 的应用入口放至 `~/.local/share/kglobalaccel/vicinae.desktop`，用 `doRegister` 登记 `_launch`，再用 `setShortcut` 的 `SetPresent | NoAutoloading` 标志设置当前组合键。KDE 持久化为 `~/.config/kglobalshortcutsrc` 中 `[services][vicinae.desktop]` 的 `_launch=Meta+Space`。`getGlobalShortcutsByKey` 返回此动作，直接调用已登记的动作让实际会话中的 `vicinae state open` 成功。 [KDE 菜单编辑器源码](https://github.com/KDE/kmenuedit/blob/master/globalaccel.cpp)
- 用户截图中的 KRunner 输入 `vic` 时没有 Vicinae。桌面入口可由 `gio launch` 执行。部分 KDE 服务缓存已有 Vicinae，但不同环境生成的缓存文件不同。用正在运行的 KRunner 的进程环境执行 `kbuildsycoca6 --noincremental`，再重启 `plasma-krunner.service`，实际会话使用的缓存包含 `vicinae.desktop`。在隔离的 KWin Wayland 会话中用原版 `krunner_services` 搜索 `vic`，Vicinae 排第一。这一步没有改 KRunner 的插件开关。
- `vicinae deeplink vicinae://launch/clipboard/history` 在本机可直接呼出剪贴板历史。原先 `Meta+V` 绑定 Plasma 剪贴板，`Meta+Shift+V` 绑定 KVitals。按用户指定，用 `setForeignShortcut` 只释放 Plasma 的 `show-on-mouse-pos` 动作，再把 `Meta+V` 分配给 `~/.local/share/kglobalaccel/vicinae-clipboard-history.desktop` 的 `_launch`。KDE 持久化了两个变更。调用新动作实测能从关闭状态打开 Vicinae 剪贴板历史，原 Vicinae 主窗口动作继续绑定 `Meta+Space`。 [Vicinae 的 KDE 快捷键文档](https://docs.vicinae.com/quickstart/kde#open-a-specific-command)
- 随后交换两个启动器的按键。用 `setForeignShortcut` 先释放 Vicinae 的 `Meta+Space`，再把 KRunner 的 `Alt+Space` 换成 `Meta+Space`，最后将 `Alt+Space` 给 Vicinae。同步改了 Vicinae 快捷键入口的 `X-KDE-Shortcuts`。`kglobalshortcutsrc` 和运行中的 KGlobalAccel 都确认交换完成。KRunner 的 `Alt+F2`、`Search` 和 Vicinae 剪贴板的 `Meta+V` 保留。

## Folio 的汉字和拼音别名

- 应用 ID 为 `com.toolstack.Folio`。Vicinae 0.29.2 使用一个字符串存放别名，填入 `便笺 笔记 便签 bian jian bi ji bian qian`。同一值写入 tuf3 的 Home Manager 配置和当前用户 Vicinae 设置，重启用户服务后即时加载。
- 在隔离的 KWin Wayland 会话中检查实际搜索画面。`便笺`、`笔记`、`便签`、`bianjian`、`bian jian`、`biji`、`bi ji`、`bianqian`、`bian qian` 九个查询均以 Folio 为第一条应用结果。

## 从系统托盘移除 KDE 剪贴板图标

- 2026-11-24，通过 Plasma 面板脚本将 `org.kde.plasma.clipboard` 从系统托盘的 `General/extraItems` 中移除，并重载小组件。核对 `~/.config/plasma-org.kde.plasma.desktop-appletsrc`，启用列表从 17 项变为 16 项，剪贴板仍在 `knownItems` 中，可在系统托盘设置里重新启用。没有执行清除剪贴板历史操作。 [Plasma 系统托盘设置源码](https://github.com/KDE/plasma-workspace/blob/v6.8.3/applets/systemtray/systemtraysettings.cpp)
- 通过 KGlobalAccel 查询 Win+V，仍为 `vicinae-clipboard-history.desktop` 的 `_launch`。调用该动作，验证 `vicinae state open` 从关闭变为打开。入口执行的是 `vicinae deeplink vicinae://launch/clipboard/history`。 [Vicinae 剪贴板入口文档](https://docs.vicinae.com/deeplinks)
