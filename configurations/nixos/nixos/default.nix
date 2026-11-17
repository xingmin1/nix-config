# See /modules/nixos/* for actual settings
# This file is just *top-level* configuration.
{
  config,
  flake,
  ...
}: let
  inherit (flake) inputs;
  inherit (inputs) self;
in {
  imports = [
    self.nixosModules.default
    # self.nixosModules.gui
  ];

  networking.hostName = "nixos";

  # WSL 复用 Windows NVIDIA 驱动，不安装 Linux 内核驱动。
  wsl.useWindowsDriver = true;
  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.libraries = [config.wsl.wslLib];
}
