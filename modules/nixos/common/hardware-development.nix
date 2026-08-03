{
  config,
  flake,
  lib,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
in {
  users.users = lib.genAttrs config.myusers (_: {
    extraGroups = ["dialout"];
  });

  services.udev.packages = with pkgs; [
    libsigrok
    probe-rs-tools
  ];

  environment.systemPackages = [
    # Nixpkgs 提供的完整 TFTP 工具，同时安装 tftpd 服务端与 tftpc 客户端。
    pkgs.rs-tftpd

    # 上游 latest Release 的单二进制 TFTP 服务端/客户端，实际内容由 flake.lock 固定。
    flake.inputs.self.packages.${system}.tftp-now
  ];
}
