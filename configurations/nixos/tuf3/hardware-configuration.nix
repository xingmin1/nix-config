{
  config,
  lib,
  ...
}: {
  # Live 环境如发现更多启动所需模块，可在安装前补入。
  boot.initrd.availableKernelModules = [
    "nvme"
    "vmd"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = ["kvm-intel"];

  boot.initrd.services.lvm.enable = false;
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/286810cc-d237-49e1-a564-5e86789ee9dc";
      fsType = "ext4";
    };
    "/boot/efi" = {
      device = "/dev/disk/by-partuuid/bd722f1b-f04f-46a5-af9a-2b1a773e4ed4";
      fsType = "vfat";
      options = ["umask=0077"];
    };
    "/mnt/micron-code" = {
      device = "/dev/disk/by-uuid/20bdc11a-b3af-4b54-bac0-af4a137395cb";
      fsType = "ext4";
      options = ["noauto" "nofail" "x-systemd.device-timeout=8s"];
    };
    "/mnt/windows-c" = {
      device = "/dev/disk/by-uuid/C8907F9A907F8E26";
      fsType = "ntfs3";
      noCheck = true;
      # 从 Linux 只读访问 Windows 系统分区，首次访问时再挂载。
      options = [
        "ro"
        "nosuid"
        "nodev"
        "uid=${toString config.users.users.xmin.uid}"
        "gid=${toString config.users.groups.users.gid}"
        "umask=0077"
        "iocharset=utf8"
        "nofail"
        "x-systemd.automount"
        "x-systemd.device-timeout=8s"
      ];
    };
    "/home/xmin/code" = {
      device = "/mnt/micron-code/code";
      fsType = "none";
      depends = ["/mnt/micron-code"];
      options = ["bind" "noauto" "nofail"];
    };
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["modesetting" "nvidia"];
  hardware.nvidia = {
    # 对照开放内核模块下出现的 NVKMS 显存分配失败。
    open = false;
    modesetting.enable = true;
    prime = {
      # FX507ZM 的 PCI 地址，按 Windows PnP 查询结果填写。
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };
}
