# tuf3 的 NextKDE Dock 卡死现场

2026-11-23，Asia/Shanghai。NextKDE 为 `3e47c795ab20cf1174a36fada59e2faacbc7e9eb`，Quickshell 0.3.2，Qt 6.12.0，KWin 6.8.3。Quickshell 使用 `QSG_RHI_BACKEND=vulkan` 和 NVIDIA ICD，RTX 3060 Laptop 的驱动版本为 `595.112.07`。线程栈确认 Qt 实际采用 `threaded` 渲染循环。KWin `supportInformation` 报告 Intel Iris Xe、Mesa 26.3.0、OpenGL ES。DP-1 为 160 Hz，eDP-1 为 165 Hz。

## 现场时间线

- `11:34:47` 是 Quickshell PID `1122512` 卡住前的最后一条日志。Dock 激活微信窗口，随后桥接端返回一张 `720x391` 的窗口缩略图。这个顺序记录了当时的操作，触发条件仍需独立复现。
- `11:37:43` 到 `11:37:54` 间，`quickshell ipc --pid 1122512 show` 连续四次超过 2 秒，返回 `124`。主线程等待 futex，`QSGRenderThread` 线程 `1122853` 一直处于运行状态。
- `/proc/1122853/schedstat` 的第一个字段在 `11:38:13` 为 `211836486401` ns，在 `11:39:26` 为 `284634469064` ns。约 73 秒内增加约 72.8 秒 CPU 时间。主线程的 `62585498072` ns 同期没有变化。当时还剩约 22 GiB 可用内存，RTX 3060 采样约 `2131/6144 MiB`，内核日志未见 NVIDIA Xid、Intel GPU hang 或 OOM。
- `11:39` 通过本机认证短暂附加 GDB，获取卡住的渲染线程和界面线程，随后正常分离。渲染线程栈顶连续五帧在 `libnvidia-glcore.so.595.112.07`，下方为 QtGui 和 `QSGRenderThread::syncAndRender()`。主线程停在 `QSGThreadedRenderLoop::polishAndSync()` 的 `QWaitCondition::wait()`。这解释了整个 Quickshell 无法处理 IPC 与用户输入。后续反汇编确定了 Vulkan 入口，见下节。
- `11:40:17` 只重启 `kos-shell.service`，新 PID 为 `1162949`。重启后相同 IPC 三次分别花费 `55`、`54`、`54` ms。保留 GPU、渲染参数和悬停放大设置。重启恢复了此次故障，复发情况仍待观察。

## 其他日志和上游对照

- `11:20:14` 在 Dock 多窗口预览状态更新时有 `Binding loop detected for property "effectiveWindows"`。`11:20:17` 和 `11:20:48` 有 `ContextMenu.qml[429:-1]: TypeError: Cannot call method 'hide' of undefined`。当时 Quickshell 此后仍处理缩略图与点击事件，后一轮真正卡死也没有这两条报错。两处 QML 问题可单独调查。
- KWin 有间歇性 `Failed to allocate a graphics buffer for a swapchain`。卡死时段无同一时刻的 KWin 错误，本次栈阻塞在 Quickshell 进程里。KDE 有接近的 Intel 与 RTX 3060 双显卡问题，其表现是外屏残影。见 [KDE #527566](https://bugs.kde.org/show_bug.cgi?id=527566)。
- Quickshell 的 [GitHub #919](https://github.com/quickshell-mirror/quickshell/issues/919) 同样记录 Qt 界面线程卡在渲染同步，其复现条件是 Wayland 输出全部消失。本次日志最后可见事件是 Dock 激活窗口与缩略图返回。若要比对 Qt 的线程行为，见 [Qt Quick Scene Graph](https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph.html)。
- NVIDIA 论坛有 [Wayland Vulkan WSI 占满单核](https://forums.developer.nvidia.com/t/nvidia-wayland-vulkan-wsi-busy-spins-in-vkwaitforpresentkhr-with-vk-khr-present-wait/367887) 的报告，故障入口是 `vkWaitForPresentKHR`，与本机的 `vkDestroyImage` 不同。NextKDE 自己也修过 [弹窗 anchor 和 Dock 销毁时的崩溃](https://github.com/NextKde/NextKde/commit/7f1084b8b5)，这次栈形态为渲染同步等待。

## 追踪到 `vkDestroyImage`，并切换到 Intel

用卡死时同一份 Qt 6.12.0 二进制离线反汇编。`libQt6Gui.so.6` 的 Build ID 为 `48212d210d32e7a962e5750445ecdfa0d86c1b3c`。QtQuick 栈帧 `0x75ffafb95852` 对应 `0x595852`，前一条指令调用 `QRhi::beginFrame`。QtGui 栈帧 `0x75ffaeedc0e5` 对应 `QRhi::beginFrame` 内虚调用的返回位置 `0x4dc0e5`，得到当时 QtGui 加载基址 `0x75ffaea00000`。同一基址还原其他 QtGui 栈帧，三个返回地址都与调用指令对上。

```text
59584d: e8 4e f2 c2 ff        call   1c4aa0 <QRhi::beginFrame(QRhiSwapChain*, QFlags<QRhi::BeginFrameFlag>)@plt>
4dc0e2: ff 50 78              call   *0x78(%rax)
864b6c: e8 ff f8 ff ff        call   864470 <QRhiVulkan::prepareNewFrame(QRhiCommandBuffer*)>
8644a1: e8 5a 19 ff ff        call   855e00 <QRhiVulkan::executeDeferredReleases(bool)>
8561b6: e8 b5 bb 03 00        call   891d70 <QVulkanDeviceFunctions::vkDestroyImageView(VkDevice_T*, VkImageView_T*, VkAllocationCallbacks const*)>
8561c8: e8 43 bb 03 00        call   891d10 <QVulkanDeviceFunctions::vkDestroyImage(VkDevice_T*, VkImage_T*, VkAllocationCallbacks const*)>
8561cd: 49 8b 57 08           mov    0x8(%r15),%rdx
8561da: e8 01 b7 03 00        call   8918e0 <QVulkanDeviceFunctions::vkFreeMemory(VkDevice_T*, VkDeviceMemory_T*, VkAllocationCallbacks const*)>
891d20: ff a0 30 01 00 00     jmp    *0x130(%rax)
```

卡死记录中驱动上方第一帧的返回地址正是 `0x8561cd`。Qt 的 `vkDestroyImage` 包装函数最后直接跳转到驱动，所以原 GDB 栈没有这一行函数名。源码中 `vkDestroyImageView → vkDestroyImage → vkFreeMemory` 对应 `qrhivk_releaseRenderBuffer` 分支，处理的是延期释放的渲染缓冲区。Qt 源码说明，清理发生在新帧开始且等待旧帧信号之后。尚未确定是哪一个窗口操作引发该缓冲区的释放，也没有足够证据归责到驱动缺陷或 Qt 的对象生命周期。 [Qt 6.12.0 清理代码](https://github.com/qt/qtbase/blob/v6.12.0/src/gui/rhi/qrhivulkan.cpp#L4803-L4853) · [开始新帧](https://github.com/qt/qtbase/blob/v6.12.0/src/gui/rhi/qrhivulkan.cpp#L2914-L2928) · [Vulkan 的销毁约束](https://docs.vulkan.org/refpages/latest/refpages/source/vkDestroyImage.html)

查了 Qt/Quickshell GitHub、NVIDIA 595/615 Linux 发行说明、NVIDIA 开发者论坛及 KDE 社区。没有找到明确修复本机这条 `vkDestroyImage` 栈的已发布版本。Omarchy 的 Quickshell 维护者说明，混合显卡机器在核显承担显示输出时无需强制走 NVIDIA。此处保留 Vulkan 与 `threaded`，只用 `VK_DRIVER_FILES` 选择 Intel ICD。两个已连接的 DRM 输出 DP-1 和 eDP-1 都归属 Intel PCI `0000:00:02.0`，RTX 为 `0000:01:00.0`。 [Omarchy #7268](https://github.com/omacom/omarchy/issues/7268) · [Khronos Loader 的 ICD 选择](https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderDriverInterface.md#overriding-the-default-driver-discovery) · [NVIDIA 595.112.07 发行说明](https://www.nvidia.com/en-us/drivers/details/283706/)

- 用单独的 KWin 虚拟会话、Wayland socket、D-Bus 和配置目录做后台对照，实际桌面没有合成鼠标事件。两个 GPU 依次通过 Qt Quick 4× MSAA 图层尺寸变化测试，原输出均为 `RELEASE_PROBE_PASS frames=540 reallocations=180`。这个短测没有复现 RTX 原卡死。
- 两块 GPU 的 NextKDE 自带悬停放大测试均输出 `DOCK_MAGNIFICATION_PASS`，覆盖底部、左侧和右侧。达到 90% 放大效果的时间依次为 RTX `62/70/69 ms`，Intel `64/75/81 ms`。这些数字来自虚拟会话，实际双屏帧率与真实缩略图时序未由该夹具测量。另一个上游应用名称扫过测试在两块卡上均有 `SWEEP_FAIL continuous name selection`，`1800` 和 `360` 速度均可见。应用名称选择与本次 Vulkan 图像释放故障是两条线索。
- 依用户要求先切换实际 NextKDE。配置由 `nvidia_icd.json` 改为 `intel_icd.x86_64.json`，其他行在生成文件中相同。通过现有 `~/.local/state/nextkde-dock-service-config` 指向新构建的配置，只重启 `kos-shell.service`。新进程 PID `1175340` 的 Vulkan manifest 指向 Intel，打开的 GPU 渲染节点只有 `/dev/dri/renderD128`，对应 Intel 的 PCI 地址。Dock 设置返回 `hoverScale: 1.2`、`visibilityMode: always`。RTX 驱动和其他应用的设置保留。
- 11:51:47 切换生效后，八次连续 `quickshell ipc show` 用时依次为 `36 / 42 / 41 / 43 / 56 / 48 / 45 / 53 ms`。到 11:53:34，实际会话还在持续收到 `thumbnail ready`，Quickshell 没有自动重启。日志确认缩略图生成和接收，单张图在指针移开前是否绘制到屏幕仍未量测。
- 本机生成的配置文件经过 Nix 单独构建，并用同一输出应用到当前会话。恢复以前的显卡设置时，把同一 Nix 配置的 manifest 改回 `nvidia_icd.json` 并重新构建局部配置即可。切换规避了现场捕捉到的 NVIDIA Vulkan 路径，仍需日常使用确认没有复发。

## 切换 NVIDIA Open 内核模块

- 用户选定 NVIDIA Open 后，在 `configurations/nixos/tuf3/hardware-configuration.nix` 设 `hardware.nvidia.open = true`。内核仍为 `6.18.63`，驱动仍为 `595.112.07`。对构建产物运行 `modinfo -b "$candidate/kernel-modules" -k 6.18.63 -F license nvidia` 返回 `Dual MIT/GPL`，`-F version` 返回 `595.112.07`。NextKDE 继续使用 Intel ICD。
- 整机构建曾报 `mismatch in field 'narHash'`。`justLspRelease`、`genofficeRelease`、`genofficeNpmLock`、`officecliRelease` 和 `nbCliRelease` 刷新锁定记录后仍解析到已安装的发行版本。UU Remote Linux / Magpie 的最新发行已变，改用已安装版本 `v0.2.62` / `v0.1.4634` 的 GitHub Release 标签 URL。`nix build --no-update-lock-file '.#nixosConfigurations.tuf3.config.system.build.toplevel'` 构建成功，`nix flake check --no-update-lock-file` 通过。
- 13:11 通过 `sudo nixos-rebuild boot --store-path <已构建的系统>` 将第 41 代设为下次启动默认项，第 40 代仍可回退。`boot` 操作后当前的 `/proc/driver/nvidia/version` 仍返回 `NVIDIA UNIX x86_64 Kernel Module 595.112.07`。重启后核验该文件应报告 `Open Kernel Module`，并用 `nvidia-smi` 检查 RTX 3060 是否正常识别。写入启动项时没有重启桌面会话。

## 文件管理器安装与关联的经验

- 七个试用软件为 Favnyr、Spacedrive、Sigma File Manager、Xplorer、Strata、Flea、Double Commander。Flea 和 Strata 体验也不错，最终保留 Favnyr。Favnyr 0.3.8 使用上游 Nix Flake 里的发布二进制，提交 `33e0e446d7a0dec43d3bfacd295abfae4b87afeb`。
- Double Commander 来自用户 Nix profile，用 `nix profile remove doublecmd` 卸载。其他五个试用版的桌面入口和安装目录 `~/.local/share/file-manager-trials` 移到回收站，应用偏好和数据目录保留。用 `xdg-mime query default inode/directory` 和 `gio mime inode/directory` 验证 Favnyr，用 `kioclient exec <目录> inode/directory` 验证 KDE 实际启动它。
- 新的目录关联是 `inode/directory=favnyr.desktop`。截图里的 Markdown 仍走原有 `text/markdown=arcmd.desktop`。从 NextKDE 启动的 Favnyr 继承 Shell 单元的精简 `PATH`，其中没有 `/etc/profiles/per-user/xmin/bin`。KIO 能根据 XDG 数据目录查到 ArcMD 的桌面入口，但其中的 `Exec=arcmd %U` 在该路径下找不到程序。
- 本机用户级 `arcmd.desktop` 设 `Exec=/etc/profiles/per-user/xmin/bin/arcmd %U` 即时修复。包配置将桌面入口改为 Nix 输出的绝对路径。保留已安装 ArcMD 0.2.5，固定该版本的官方校验清单。版本 URL 的清单与旧锁文件的 NAR 哈希相同。以受限 `PATH` 运行 `kde-open` 打开实际 Markdown，`11:37:24` 日志显示 `Started ArcMD.`，进程参数含该文件。

## GDB 原始栈节选

```text
Thread 16 (Thread 0x75ff073ff6c0 (LWP 1122853) "QSGRenderThread"):
#0  0x000075ffa66c88df in ?? () from /nix/store/0cf8pz1kfhcnsc4017yjj410dhzkjd34-nvidia-x11-595.112.07/lib/libnvidia-glcore.so.595.112.07
#1  0x000075ffa665d310 in ?? () from /nix/store/0cf8pz1kfhcnsc4017yjj410dhzkjd34-nvidia-x11-595.112.07/lib/libnvidia-glcore.so.595.112.07
#2  0x000075ffa6661d04 in ?? () from /nix/store/0cf8pz1kfhcnsc4017yjj410dhzkjd34-nvidia-x11-595.112.07/lib/libnvidia-glcore.so.595.112.07
#3  0x000075ffa6a9f3d4 in ?? () from /nix/store/0cf8pz1kfhcnsc4017yjj410dhzkjd34-nvidia-x11-595.112.07/lib/libnvidia-glcore.so.595.112.07
#4  0x000075ffa69f99ea in ?? () from /nix/store/0cf8pz1kfhcnsc4017yjj410dhzkjd34-nvidia-x11-595.112.07/lib/libnvidia-glcore.so.595.112.07
#5  0x000075ffaf2561cd in ?? () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Gui.so.6
#6  0x000075ffaf2644a6 in ?? () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Gui.so.6
#7  0x000075ffaf264b71 in ?? () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Gui.so.6
#8  0x000075ffaeedc0e5 in ?? () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Gui.so.6
#9  0x000075ffafb95852 in QSGRenderThread::syncAndRender() () from /nix/store/lj6375av7i0ariikwkkd5dck5qhwsz73-qtdeclarative-6.12.0/lib/libQt6Quick.so.6
#10 0x000075ffafb96d61 in QSGRenderThread::run() () from /nix/store/lj6375av7i0ariikwkkd5dck5qhwsz73-qtdeclarative-6.12.0/lib/libQt6Quick.so.6
#11 0x000075ffad7ddd40 in QThreadPrivate::start(void*) () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Core.so.6

Thread 1 (Thread 0x75ffab654400 (LWP 1122512) ".quickshell-wra"):
#0  0x000075ffacca8472 in __syscall_cancel_arch () from /nix/store/r3hvhzl5fxhrgn0rfy5g7rda17702pj4-glibc-2.44-57/lib/libc.so.6
#1  0x000075ffacc9bf69 in __futex_abstimed_wait_cancelable64 () from /nix/store/r3hvhzl5fxhrgn0rfy5g7rda17702pj4-glibc-2.44-57/lib/libc.so.6
#2  0x000075ffacc9ebd4 in pthread_cond_wait@@GLIBC_2.3.2 () from /nix/store/r3hvhzl5fxhrgn0rfy5g7rda17702pj4-glibc-2.44-57/lib/libc.so.6
#3  0x000075ffad7e70b3 in QWaitCondition::wait(QMutex*, QDeadlineTimer) () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Core.so.6
#4  0x000075ffafb990be in QSGThreadedRenderLoop::polishAndSync(QSGThreadedRenderLoop::Window*, bool) () from /nix/store/lj6375av7i0ariikwkkd5dck5qhwsz73-qtdeclarative-6.12.0/lib/libQt6Quick.so.6
#5  0x000075ffaf92271e in QQuickWindow::event(QEvent*) () from /nix/store/lj6375av7i0ariikwkkd5dck5qhwsz73-qtdeclarative-6.12.0/lib/libQt6Quick.so.6
#6  0x000075ffb01ac17e in QApplicationPrivate::notify_helper(QObject*, QEvent*) () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Widgets.so.6
#7  0x000075ffad5cfd98 in QCoreApplication::notifyInternal2(QObject*, QEvent*) () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Core.so.6
#8  0x000075ffaec71bd3 in ?? () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Gui.so.6
#9  0x000075ffad646d9e in QObject::event(QEvent*) () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Core.so.6
#10 0x000075ffb01ac17e in QApplicationPrivate::notify_helper(QObject*, QEvent*) () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Widgets.so.6
#11 0x000075ffad5cfd98 in QCoreApplication::notifyInternal2(QObject*, QEvent*) () from /nix/store/12sd69v2zqs0x4xys6af45hcck74mjhl-qtbase-6.12.0/lib/libQt6Core.so.6
[Inferior 1 (process 1122512) detached]
```
