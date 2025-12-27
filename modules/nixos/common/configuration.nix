# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL
{
  flake,
  config,
  lib,
  pkgs,
  ...
}:
rec {
  imports = [
    # include NixOS-WSL modules
    flake.inputs.nixos-wsl.nixosModules.default
  ];

  wsl.enable = true;
  wsl.defaultUser = "xmin";
  wsl.wslConf.interop.appendWindowsPath = false;
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
    podman-compose
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings = {
    extra-substituters = [ "https://numtide.cachix.org" ];
    extra-trusted-public-keys = [ "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=" ];
  };

  # 避免 sshd 服务启动失败
  services.openssh.ports = [ 2222 ];

  # 当系统用户默认 shell = pkgs.zsh 时，按 NixOS 要求必须启用系统级 zsh，以确保 PATH 与 /etc/shells 设置正确。
  # 参见错误提示：users.users.<name>.shell = zsh 但 programs.zsh.enable 未开启将导致登录可能失败。
  # programs.fish.enable = true;
}
