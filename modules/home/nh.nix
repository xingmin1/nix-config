{ config, ... }:
{
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/${config.home.username}/nix-config"; # sets NH_OS_FLAKE variable for you
  };
}