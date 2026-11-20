# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{pkgs, ...}: {
  nixpkgs.hostPlatform = "x86_64-linux";

  # 生成/启用 /etc/containers 下的通用容器配置文件支持
  virtualisation.containers.enable = true;

  virtualisation.podman = {
    enable = true;

    # 可选：提供 `docker` 命令别名 -> podman（很多工具会直接调用 docker）
    dockerCompat = true;

    # 可选：podman-compose 等场景下，容器互相解析/通信更顺滑
    defaultNetwork.settings.dns_enabled = true;
  };

  # 可选：你还可以装一些常用工具
  environment.systemPackages = with pkgs; [
    bubblewrap
    podman-compose

    # 需要 root 权限的系统与块设备工具
    kmod
    bmaptool
  ];

  nix.settings.experimental-features = [
    "cgroups"
    "nix-command"
    "flakes"
  ];

  nix.gc.automatic = false;
  nix.settings = {
    extra-substituters = [
      "https://numtide.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  # 当系统用户默认 shell = pkgs.zsh 时，按 NixOS 要求必须启用系统级 zsh，以确保 PATH 与 /etc/shells 设置正确。
  # 参见错误提示：users.users.<name>.shell = zsh 但 programs.zsh.enable 未开启将导致登录可能失败。
  programs.fish.enable = true;
  programs.zsh.enable = true;
}
