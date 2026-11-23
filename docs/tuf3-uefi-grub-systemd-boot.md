# tuf3 的 UEFI 双系统引导调查

调查日期：2026-11-23。调查基线：`83ed7cc`。本次只读取系统状态，保留 UEFI GRUB。若今后希望开机时在一个菜单直接选 Windows 和 NixOS，再考虑 systemd-boot。

## 本机布局与实测

| 磁盘和分区 | 容量 | 作用 |
| --- | --- | --- |
| 致态 TiPlus7100 `nvme0n1p3` | 512 MiB | FAT32 ESP，挂载在 `/boot/efi`，GRUB 和 Windows 主引导均注册在这里 |
| 致态 `nvme0n1p2` | 1.3 TiB | Windows C 盘，Linux 下挂载在 `/mnt/windows-c` |
| 致态 `nvme0n1p5` | 600 GiB | ext4，挂载 `/` 和 `/nix/store` |
| Micron 3400 `nvme1n1p1` | 260 MiB | FAT32 ESP，固件中登记为 Windows 备用引导 |
| Micron `nvme1n1p8` | 200 MiB | FAT32，GPT 类型为 Windows 恢复分区，未出现在上述 UEFI 引导记录中 |

从 EFI 变量及 `bootctl --no-pager status` 读取的入口：

```text
BootCurrent=0000
BootOrder=0000,0002,0001,0003,0004,0005,0006
0000 NixOS (ZHITAI)                     bd722f1b-f04f-46a5-af9a-2b1a773e4ed4  \EFI\NixOS-boot-efi\grubx64.efi
0002 Windows Boot Manager               bd722f1b-f04f-46a5-af9a-2b1a773e4ed4  \EFI\Microsoft\Boot\bootmgfw.efi
0001 Windows Boot Manager (Micron fallback) 1370684c-3ef7-49d1-8f7e-28cee989674d  \EFI\Microsoft\Boot\bootmgfw.efi
```

分区类型用 `lsblk -o NAME,SIZE,PARTTYPE,PARTLABEL,FSTYPE,MOUNTPOINTS /dev/nvme0n1 /dev/nvme1n1` 核实。普通用户读取 ESP 文件和 `/boot/grub/grub.cfg` 遇到权限限制。本次没有重启 Windows 验证主、备用入口。UEFI 变量记录可确认登记位置，实际可启动性要另测。

`df -B1 --output=size,used,avail,target /boot/efi`：

```text
1B-blocks     Used     Avail Mounted on
532676608 37015552 495661056 /boot/efi
```

`systemd-analyze time`：

```text
Startup finished in 37.987s (firmware) + 5.859s (loader) + 1.301s (kernel) + 2.318s (initrd) + 10.799s (userspace) = 58.267s
```

这次启动计时中固件阶段占约 65%。只有 GRUB 这一份计时。换引导器的速度收益需用同一台机器、相同菜单等待时间做对照。

## NixOS 的实际差别

`tuf3` 的 [引导配置](../configurations/nixos/tuf3/default.nix#L48) 启用 GRUB EFI，`configurationLimit = 10`，`canTouchEfiVariables = false`。评估结果还显示 `grub.copyKernels = false`、`grub.useOSProber = false`、`grub.extraEntries = ""` 和 `systemd-boot.enable = false`。当前启动的 `BOOT_IMAGE` 路径指向 ext4 上的 `/nix/store`。

- 同一个 ESP 上存在 `EFI/Microsoft/Boot/bootmgfw.efi` 时，systemd-boot 会自动显示 Windows。这个条件适用于致态盘登记的主引导。Micron 的备用入口继续由固件管理。
- 当前 GRUB 直接读 ext4 上的 NixOS 内核和 initrd。当前锁定的 Nixpkgs 使用 systemd-boot 时，会把菜单所需的内核和 initrd 写到 ESP 的 `EFI/nixos/`，同一目标路径只写一次。若另设同一磁盘的 XBOOTLDR，可把这些文件放在那里。
- 从 `/nix/var/nix/profiles/system-{31..40}-link` 逐代解析 `kernel` 和 `initrd` 得到 3 个不同文件。内核 `13,902,336` 字节被 10 代共用，两个 initrd 分别为 `43,467,464` 字节（9 代）和 `43,465,375` 字节（1 代）。合计 `100,835,175` 字节（约 96.2 MiB），低于目前的 472.7 MiB 空闲。实际写入还需计入菜单、引导程序及可能的额外启动文件。
- 以当前每套约 54.7 MiB 估算，十套互不共用的内核和 initrd 约为 547 MiB。若将来迁移，应根据文件去重后的实际体积设置代数上限，并为下一次更新预留空间。社区有写入新 initrd 时空间不足、重建失败的实测报告。
- 源码在禁用 EFI 变量写入时为 `bootctl` 传 `--variables=no`。即使构建过程写入 systemd-boot 的 EFI 文件，现有 `Boot0000` 仍指向 GRUB。今后若试用，要先备份 ESP 文件与固件入口，确认两个系统和需要的 NixOS 回滚入口均可启动，再决定是否更改默认项。

## 来源

- [NixOS Wiki：Windows 双启动与同一 ESP 的自动检测](https://wiki.nixos.org/wiki/Dual_Booting_NixOS_and_Windows#systemd-boot)
- [NixOS Wiki：引导器及保留内核和 initrd 的位置](https://wiki.nixos.org/wiki/Bootloader)
- [NixOS Discourse：引导菜单能否发现其他磁盘的 Windows](https://discourse.nixos.org/t/add-windows-to-boot-menu/40675)
- [NixOS Discourse：复制 initrd 时启动分区用满](https://discourse.nixos.org/t/failed-rebuild-due-to-not-enough-space-in-boot/65649)
- [当前锁定的 Nixpkgs：systemd-boot 模块](https://github.com/NixOS/nixpkgs/blob/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55/nixos/modules/system/boot/loader/systemd-boot/systemd-boot.nix)
- [当前锁定的 Nixpkgs：引导文件去重与 EFI 变量写入](https://github.com/NixOS/nixpkgs/blob/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55/nixos/modules/system/boot/loader/systemd-boot/systemd-boot-builder.py)
- [systemd 上游：ESP 和 XBOOTLDR 的文件读取规则](https://www.freedesktop.org/software/systemd/man/251/systemd-boot.html)
