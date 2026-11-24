# TUF3 WPS 与睡眠/休眠排查记录（2026-11-25）

## 本次安装与搜索工具

- Octocode CLI 安装在用户级 Node 前缀，入口为 `~/.local/bin/octocode`，不放进 `~/.agents`。
- Octocode Research Skill 位于 `~/.agents/skills/octocode-research`。
- 本地 `nixos-research` Skill 位于 `~/.agents/skills/nixos-research`。
- MCP-NixOS 通过 Codex 全局 MCP 配置使用 `nix run github:utensils/mcp-nixos --`。
- Grep.app 通过 Codex 全局 MCP URL `https://mcp.grep.app` 使用。
- 这两个 MCP 没有作为常驻后台服务启动。

## WPS 的公开 Nix 配置对照

### 主要实现方式

多个 Nix 配置仓库使用 `makeWrapper` 或 `wrapProgram` 给 WPS 启动器设置以下变量：

```nix
--set XMODIFIERS "@im=fcitx"
--set GTK_IM_MODULE "fcitx"
--set QT_IM_MODULE "fcitx"
```

代表实现：

- https://github.com/fym998/nur-packages/blob/main/pkgs/by-name/wpsoffice-cn-fcitx.nix
- https://github.com/aleadag/nix-configs/blob/master/packages/wpsoffice-cn-fcitx/default.nix
- https://github.com/ccicnce113424/nixos-config/blob/master/home/ccicnce113424/documents/default.nix

Gentoo 的 WPS 12.1.2 打包脚本只对 `wps`、`et`、`wpp`、`wpspdf` 启动器设置 `QT_IM_MODULE`，并说明 WPS 自带 X11-only Qt，Wayland 下通过 XWayland 运行：

- https://github.com/gentoo-zh/overlay/blob/master/app-office/wps-office/wps-office-12.1.2.29183.ebuild

Nixpkgs 官方 WPS 包主要处理动态库和安装路径，没有给首页 CEF 搜索框增加特殊输入法补丁：

- https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/wp/wpsoffice/package.nix

### 本机 WPS 结论

当前文档编辑器可使用 WeTypeX，首页搜索框仍不能输入中文。进程检查显示 WPS 主编辑器使用 Qt，首页搜索框由内嵌 CEF 页面提供。公开配置没有找到可信的 CEF 子进程修复方式，因此没有保留自定义 CEF 包装方案。

## 本机睡眠与休眠现状

当前配置在 `configurations/nixos/tuf3/default.nix`：

- `systemd.sleep.settings.Sleep.MemorySleepMode = "deep"`，避免本机已知的 s2idle 进入问题。
- 日常交换使用 zram。
- 休眠使用 `/hibernate.swap`，大小 48 GiB，优先级低于 zram。
- `systemd-hibernate.service` 在休眠时临时关闭 PCI PEG1 唤醒，恢复后再打开。
- NVIDIA 使用 open 内核模块和 `hardware.nvidia.powerManagement.enable = true`。

本机当前状态：

```text
/sys/power/mem_sleep: [s2idle] deep
/sys/power/state: freeze mem disk
zram0: 19.4 GiB, priority 5
/hibernate.swap: 48 GiB, priority 1
kernel: 6.18.63
```

## 本机日志证据

上一轮启动日志显示：

```text
18:32:25 进入 ACPI S4
18:32:25 从 S4 恢复
18:40:28 i915 GPU HANG: ecode 12:1:85dffffb, in QSGRenderThread
18:40:28 i915 QSGRenderThread context reset due to GPU hang
20:40:06 PM: suspend entry (deep)
20:50:09 PM: suspend resume from S3
20:50:09 spd5118_resume returns -6
20:50:09 ucsi_acpi failed to re-enable notifications (-110)
20:50:10 PM: suspend exit
```

因此目前能确认三类问题：

1. **严重问题是 Intel i915 的 GPU HANG**。进程名为 `QSGRenderThread`，对应 Qt Quick 渲染线程。它发生在恢复之后，足以造成桌面黑屏或 KWin/Plasma 图形上下文丢失。
2. `spd5118_resume returns -6` 是 DDR5 SPD 温度传感器在恢复时的 I2C 临时错误。社区报告中它通常不会单独造成关机，但说明恢复路径存在设备状态未完全恢复。
3. `ucsi_acpi ... -110` 是 USB-C UCSI 控制器恢复通知超时。社区报告中同样常见于 s2idle/S3 恢复，可能影响 USB-C/扩展坞状态。

## 社区与 GitHub 对照

- Framework 社区报告了与本机完全相同的 `spd5118_resume -6` 和 `ucsi_acpi -110`，并指出这些错误只在恢复路径出现，冷启动正常。该报告还提到较新的内核包含 spd5118 临时 I2C 错误修复：
  https://community.frame.work/t/display-stays-black-after-lid-suspend-resume-several-devices-fail-to-resume-from-s2idle/85611
- Bazzite 的 Intel 混合显卡报告出现同类 `i915 GPU HANG ... QSGRenderThread`、GuC reset 失败和 KDE 图形重置。报告指出问题跨 Qt Quick、Chromium、Plasma 等应用，倾向于 Intel 驱动/固件路径，而非某个单独应用：
  https://github.com/ublue-os/bazzite/issues/6029
- NixOS Discourse 上的 Alder Lake/Raptor Lake 黑屏方案使用 `i915.enable_psr=0`，原因是 Panel Self Refresh 恢复后导致显示管线无法重新启用：
  https://discourse.nixos.org/t/fix-freeze-after-wake-from-sleep-suspend-with-intel-raptor-lake-and-alder-lake-p/51677
- NixOS Hardware 对多款 Intel 笔记本使用 `i915.enable_psr=0` 解决闪屏或显示异常：
  https://github.com/NixOS/nixos-hardware/blob/master/dell/xps/13-9315/default.nix
  https://github.com/NixOS/nixos-hardware/blob/master/dell/latitude/9430/default.nix
- 其他公开 Nix 配置在更顽固的黑屏场景中同时使用 `i915.enable_psr=0` 和 `i915.enable_dc=0`：
  https://github.com/ChrisLAS/hyprvibe/blob/master/hosts/nixvader/system.nix
  https://github.com/andre-brandao/nixos/blob/master/modules/nixos/programs/niri.nix
- 休眠配置的共同点是显式设置 `boot.resumeDevice`。使用 swapfile 时，Btrfs 还需要 `resume_offset`。本机是 ext4 根文件系统加独立 ext4 swapfile，目前 systemd EFI 记录已经成功完成过一次 S4 恢复，但仍应继续核对生成的 initrd 和恢复路径：
  https://github.com/chouzan/nixos-config/blob/master/docs/TROUBLESHOOTING.md
  https://github.com/Mcarnon/Nixos-Configuration/blob/main/hosts/laptop/hardware-configuration.nix

## 当前改动与验证计划

已加入：

```nix
boot.kernelParams = [
  "i915.enable_psr=0"
  "i915.enable_dc=0"
];
```

这两个参数先用于验证恢复稳定性。代价是 Intel 显示省电功能降低，尤其是 `i915.enable_dc=0` 可能增加功耗。尚未宣称它已经完全解决 GPU HANG。

验证顺序：

1. 先执行 `nix flake check` 和 `nix build .#nixosConfigurations.tuf3.config.system.build.toplevel`。
2. 应用新代际后重启，使内核参数生效。
3. 记录 `/proc/cmdline`、`journalctl -b -1 -k`、`journalctl -b -1 -u systemd-suspend.service -u systemd-hibernate.service`。
4. 分别测试短时间 `systemctl suspend`、合盖深睡、`systemctl hibernate`，每次确认双屏恢复、USB-C、输入设备和 Qt Quick 图形是否正常。
5. 若仍出现 `QSGRenderThread GPU HANG`，再单独对比 `QT_QUICK_BACKEND=software` 的问题应用，避免立即关闭整个桌面的 GPU 加速。
6. 休眠若出现恢复失败，再核对 `/hibernate.swap` 的 UUID、EFI `HibernateLocation` 和 initrd 中的 resume 配置，不直接猜测 `resume_offset`。
