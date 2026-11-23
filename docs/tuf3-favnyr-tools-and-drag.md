# Favnyr 可选工具和跨应用拖拽

2026-11-23，tuf3 的 KDE Plasma Wayland 会话。Favnyr 为 `0.3.8`，使用上游提交 `33e0e446d7a0dec43d3bfacd295abfae4b87afeb` 提供的 Nix 包，包内解包官方 Linux 发布二进制。

## 可选工具

设置页把 `ffmpeg`、`poppler-utils` 和 `7-Zip` 都显示为「未找到」。终端已能从 `/etc/profiles/per-user/xmin/bin/ffmpeg` 找到 FFmpeg，Dock 启动的 Favnyr 进程使用更短的 `PATH`，该目录未出现在进程环境里。环境差异与此前从 Favnyr 打开 Markdown 找不到 ArcMD 的原因相近。

- Favnyr 的 `optional_tools_info()` 按进程 `PATH` 查找 `ffmpeg`、`pdftoppm` 或 `pdftocairo`，以及 `7zz`、`7z` 或 `7za`。检测版本分别使用 `ffmpeg -version`、Poppler 的 `-v` 和 7-Zip 的 `i`。上游优先选 `7zz`，便于处理 Zstandard 压缩的 Blender 文件。 [上游帮助](https://github.com/GlitchAwakened/Favnyr#thumbnails)
- NixOS 主机配置用 `symlinkJoin` 包装原 Favnyr，启动时把 Nixpkgs 的 `ffmpeg`、`poppler-utils` 和 `_7zz` 追加到应用的搜索范围。包内 `favnyr.desktop` 的 `Exec` 使用包装器绝对路径。当前用户级桌面快捷方式沿用 `~/.nix-profile/bin/favnyr`，该入口已指向新包装器。
- `nix profile` 先加入新输出并确认命令可用，再移除旧的 `packaging/nix` 项。其余用户 profile 项保持原版本。`xdg-mime query default inode/directory` 仍返回 `favnyr.desktop`。KDE 通过目录关联启动的新进程以自己的 `PATH` 成功运行 FFmpeg `9.0.2`、Poppler `26.11.0` 和 7-Zip `26.04`。用该环境实际生成了视频和 PDF 的 PNG，并压缩、解压了测试 PDF，字节一致。旧进程的环境随窗口关闭而结束。
- 可选工具检测成功后，Favnyr 0.3.8 仍要求保存「现成命令」的模板，右键菜单才会显示压缩项。本机原先没有 `~/.local/share/favnyr/openers.toml`。在独立 KWin 会话用官方压缩模板的等效配置确认「压缩到…」会打开内置选项对话框，再用界面把 `archive probe.txt` 压成同名 ZIP。用 `ZipFile.testzip()` 及文件内容逐字节比较确认成功后，写入实际用户配置。记录为 `program = "7zz"`、`archive_dialog = true`、`ctx_menu = 3`、`ctx_exts = ["*"]`，且参数为 `["a", "{dir}/{setname}.zip", "{files}"]`。`ctx_menu = 3` 同时在文件和文件夹右键菜单显示。旧窗口需重新打开才能载入这条记录。

- NixOS 主机 `tuf3` 通过 Home Manager 激活脚本补齐 Favnyr 0.3.8 的三个官方 7-Zip 模板。「解压到此处」执行 `7zz x -o{dir} {file}`，「解压到文件夹」执行 `7zz x -o{dir}/{stem} {file}`。两个解压项使用上游的扩展名白名单。脚本保留用户已有的命令和注释，兼容 `openers = []` 和 `[[openers]]`，已有同一模板或等效命令时跳过。首次测试发现 TOML 库会把普通记录写成表头，使内联数组无效，改用内联表并在替换文件前重新校验。实测了空配置、已有命令、模板去重和重复激活。通过隔离的 KWin 会话从 Favnyr 右键菜单执行两项解压，分别在当前目录和同名子目录得到与原文件一致的内容。

## 打开方式缺少应用

- Favnyr 0.3.8 的 `mime_for_ext` 把 `.md`、`.txt` 和 `.log` 都映射到 `text/plain`。本机 ArcMD 的桌面文件声明 `MimeType=text/markdown;application/x-arcmd;`，因此不会进入 Markdown 候选。勾选「显示其他应用」只放宽到未声明 MIME 类型的程序，仍排除声明不同类型的程序。包内置选择器自己读取 XDG 下的 `.desktop` 文件，且没有按 KDE 已配置的 MIME 关联查询。 [Favnyr 筛选源码](https://github.com/GlitchAwakened/Favnyr/blob/33e0e446d7a0dec43d3bfacd295abfae4b87afeb/crates/favnyr-gui/src/openwith.rs#L668-L756)
- 配置增加「用 KDE 选择应用…」作为文件右键命令，使用 KIO 的 `ApplicationLauncherJob` 和默认窗口交互。Favnyr 包装器补上用户及系统 profile 的程序和应用目录，以及 Flatpak 的应用目录。整机构建通过，独立 KWin 会话里确认 Favnyr 显示了新菜单并调用了辅助程序。提交时还在验证 KDE 对话框出现以及选中应用能否收到原文件路径。这一版尚未应用到日常 Favnyr。 [KDE API](https://api.kde.org/kio-applicationlauncherjob.html)

## 跨应用拖拽

在 `crates/favnyr-gui/src/bridge.rs` 的 `on_start_native_drag` 回调中，离开窗口时调用原生文件拖拽的分支是 `cfg(windows)`，使用 Windows OLE 的 `CF_HDROP`。Linux 分支只复位原生拖拽状态。包锁定 Slint `1.18.1`、winit `0.30.13`。Favnyr 的同一窗口内部的面板拖拽由自己的界面处理。维护者在 [Favnyr #60](https://github.com/GlitchAwakened/Favnyr/issues/60) 说明原生 Wayland 跨应用拖拽在等待 winit `0.31` 与 Slint 集成。这也解释了为什么切换到 XWayland 对当前 Favnyr 的拖出实现无效。 [winit 跟踪](https://github.com/rust-windowing/winit/issues/1881) · [Slint 跟踪](https://github.com/slint-ui/slint/issues/1967)

Wayland 下的文件复制粘贴由另一套代码实现。`crates/favnyr-gui/src/clipboard.rs` 通过 `wl-clipboard-rs` 写 `text/uri-list` 和 KDE/GNOME 文件标记，可向能接收文件剪贴板的目标粘贴。要打开文件可用右键「打开方式」。需要目标应用接收真正的拖拽事件时，可以从系统带的 Dolphin 拖出。

### 跨应用拖拽复测

- 2026-11-23 核对了 [Favnyr 最新发行版](https://github.com/GlitchAwakened/Favnyr/releases/tag/v0.3.8)、[主分支的拖拽代码](https://github.com/GlitchAwakened/Favnyr/blob/main/crates/favnyr-gui/src/bridge.rs#L4779-L4836) 和 [维护者答复](https://github.com/GlitchAwakened/Favnyr/issues/60)。现有发布版和主分支的原生拖出仍是 Windows 专用。winit 的新接口已合入，`0.31.0-beta.4` 为预发行版，Slint 1.19.0 的 winit 后端仍申明 `0.30` 依赖。即使换依赖版本，Favnyr 的 Linux 出站回调也要接入新的拖拽实现。 [winit 拖拽 API](https://github.com/rust-windowing/winit/pull/4571) · [winit 预发行版](https://github.com/rust-windowing/winit/releases/tag/v0.31.0-beta.4) · [Slint 依赖](https://github.com/slint-ui/slint/blob/v1.19.0/internal/backends/winit/Cargo.toml)
- 类似项目有为 winit 0.30 自行补 Wayland 协议的办法，属于应用和后端联动的源码补丁。Wayland 的 `wl_data_device.start_drag` 需要发出按键事件的序号和起始 surface，普通的独立脚本无法把 Favnyr 窗口内已有的那次按住操作接管成系统拖拽。 [PhotoCraft 社区补丁](https://github.com/storytold/photocraft/issues/1893) · [Wayland 核心协议](https://wayland.app/protocols/wayland#wl_data_device:request:start_drag)
- 原生对照使用本机 KWin 6.8.3 的 `--virtual` 会话、独立 Wayland socket、D-Bus 及 XDG 数据目录。用合成指针只操作该虚拟会话。从 Favnyr 的测试文件 `drag probe 中文.txt` 拖到另一个应用。Favnyr 协议日志出现 `wl_pointer.button` 按下和松开，接收端随后收到普通的 `wl_pointer.enter`，期间没有 `wl_data_device.start_drag` 或 `wl_data_device.drop`。
- 可用的折衷是 [Dragon Drop 1.2.0](https://github.com/mwh/dragon/tree/v1.2.0)。从 Nixpkgs 构建/获取 `dragon-drop`，在测试用 Favnyr 的 `openers.toml` 新增文件右键项。程序是 `dragon-drop` 的绝对路径，三个参数为 `--all`、`--and-exit`、`{files}`，设置 `ctx_menu = 1`、`ctx_exts = ["*"]`。`{files}` 将选中路径以独立参数传给同一个进程。右键命令打开浮窗，再从浮窗拖入目标。
- 实测一次 GTK 接收程序，一次正式 KDE 应用 Kate。前者的接收回调记录到含空格和中文的完整文件 URI，解码后与源文件路径完全相同，后者实际打开该文件。首次对照时临时 Qt Quick 接收器只记录了 Wayland `drop` 以及 portal 文件传输请求，未给出应用层文件路径，所以用实际打开文件的 Kate 再核实。测试工具和菜单只用于虚拟会话，未写入日常 Favnyr 配置。

实际接收日志节选：

```text
wl_data_device#25.drop()
DROP_RECEIVED file:///tmp/favnyr-dnd-menu.fngI43/files/drag%20probe%20%E4%B8%AD%E6%96%87.txt
wl_data_device#14.drop()
xdg_toplevel#42.set_title("drag probe 中文.txt  — Kate")
```
