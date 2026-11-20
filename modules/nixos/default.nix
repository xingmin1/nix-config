# This is your nixos configuration.
# For home configuration, see /modules/home/*
{
  flake,
  lib,
  ...
}: {
  imports = [
    flake.inputs.self.nixosModules.common
  ];
  services.openssh.enable = lib.mkDefault true;
}
