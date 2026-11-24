# tuf3 上的 WPS 界面字体与鼠标指针

2026-11-23，WPS Office 中文版 `12.1.2.29183`。KDE Plasma Wayland，外屏 200%，内屏 175%。WPS 实际加载自带的 Qt `5.12.12` 和 XCB 插件，经 XWayland 运行。Plasma 使用 MiSans 10 和 Breeze 指针。XWayland 的 Xresources 已是 `Xft.dpi: 192`、`Xcursor.theme: breeze_cursors`、`Xcursor.size: 48`。

## 字重

- 在独立 Xvfb 显示器和临时用户目录中复现，保持 Xresources 不变。用 `FC_DEBUG=1` 记录实际匹配。WPS 界面请求 `Noto Sans CJK SC` 常规字重，Fontconfig 返回 `NotoSansCJK-VF.otf.ttc` 中的 Regular，截图中的普通字形却明显偏细。这与 Qt 5 使用 Noto CJK 可变字重的已知问题相符。 [Qt 字重报告 QTBUG-111994](https://bugreports.qt.io/browse/QTBUG-111994) · [Fedora 复现与验证记录](https://bugzilla.redhat.com/show_bug.cgi?id=2178389)
- 使用 Nixpkgs 的 `noto-fonts-cjk-sans.override {static = true;}`。WPS 专用 Fontconfig 先包含系统字体配置，再加入同一版本的静态 Noto CJK 目录，并过滤 `NotoSansCJK-VF.otf.ttc`。实际匹配改为 `NotoSansCJK-Regular.ttc`，同一 DPI 下对比，标签和搜索框字形恢复了正常粗细。
- `QT_FONT_DPI=216` 能整体放大约 12.5%，细字重仍在，窄窗口的搜索提示更早截断。`QT_SCALE_FACTOR=1.25` 和 `QT_DPI_TARGET=216` 在本版测试中没有改变主界面尺寸。`QT_QPA_PLATFORMTHEME=gtk3` 能带进指针库，字体仍然偏细。最终沿用原来的 DPI 和界面缩放。

## 指针

- 在同一个 WPS 主窗位置用 XFixes 测量。原版返回 10×16 像素的 X11 核心指针。仅设置 `XCURSOR_THEME=breeze_cursors` 和 `XCURSOR_SIZE=64`，仍为 10×16。
- 给 WPS 进程的 `LD_LIBRARY_PATH` 加入 Nixpkgs `libxcursor` 后，Qt XCB 能加载 Breeze 指针。同一 Xresources 下获取的指针缓冲区为 64×64，实际可见部分约 27×41。无需覆盖 KDE 的指针主题和全局大小。 [Qt XCB 指针加载源码](https://github.com/qt/qtbase/blob/5.12/src/plugins/platforms/xcb/qxcbcursor.cpp) · [KDE Wayland 和 XWayland 指针说明](https://blogs.kde.org/2024/10/09/cursor-size-problems-in-wayland-explained/)

## 部署

- `configurations/nixos/tuf3/wps-office.nix` 重用 WPS 的现有二进制包，包装文字、表格、演示和 PDF 的启动程序。保留桌面入口 ID、参数、图标和 MIME 声明，更新五个桌面入口的 `Exec`。配置加入主机 Home Manager，当前会话通过用户 Nix profile 先部署同一包。
- 用 Plasma 和 KRunner 的实际进程环境重建 KDE 应用索引，确认两者及 Vicinae 搜索路径都优先解析到新入口。使用正常的用户 profile 启动程序重复 Xvfb 对照，标签和搜索框的截图区域与静态字体对照逐像素一致，指针仍是 64×64 的 Breeze 缓冲区。
- WPS 包单独构建成功，Nix 格式检查和 `git diff --check` 通过。整仓检查遇到 GenOffice 的 GitHub `releases/latest` 内容哈希变化，评估 Home Manager 包单独遇到 Just LSP 的同类变化。本次沿用当前锁定的 Nixpkgs 构建 WPS，未刷新其它包的锁定输入。

## 默认打开方式

- 2026-11-23，`xdg-mime` 查询发现 PDF 和 DOC 已指向 WPS，标准 DOCX、XLS、XLSX 和 PPTX 却默认指向 `chatgpt.desktop`。Qt 还可能把同一批扩展名识别为 WPS 注册的 `application/wps-office.*`，因此同时设置标准 MIME 类型和 WPS 注册的对应类型。
- 本次设置了 33 个文档 MIME 类型，分别使用 `wps-office-pdf.desktop`、`wps-office-wps.desktop`、`wps-office-et.desktop` 和 `wps-office-wpp.desktop`。包含 PDF、DOC/DOCX、XLS/XLSX、PPT/PPTX、RTF、放映文件、常用模板和 WPS 原生文档。
- 实时更新用户的 `~/.config/mimeapps.list` 中 `[Added Associations]` 和 `[Default Applications]` 的对应键，再用桌面会话环境重建 KDE 应用索引。Home Manager 则在原有的 `kde-mimeapps.list` 中声明这些默认项。 [freedesktop.org MIME 默认项查找顺序](https://specifications.freedesktop.org/mime-apps/latest/file.html)
- 用 Qt `QMimeDatabase` 和 KDE `KApplicationTrader::preferredService` 查询 33 种文档类型、目录关联和 10 个样例文件，均匹配预期。另用仅含声明式 `kde-mimeapps.list` 的隔离配置重复验证。GIO 对 PDF、DOC/DOCX、XLS/XLSX、PPT/PPTX 的查询也给出同一组默认应用。本机 Qt 没有注册 WPS 桌面入口列出的 `application/wps-office.ofd`，因此最终移除该键。
