{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.xmin.programs.rpm;
in {
  options.xmin.programs.rpm = {
    enable = lib.mkEnableOption "rpm";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      rpm
      rpmextract
    ];
  };
}
