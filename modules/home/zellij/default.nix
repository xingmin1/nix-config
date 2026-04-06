{pkgs, ...}: let
  shellAliases = {
    "zj" = "zellij";
  };
in {
  programs.zellij = {
    enable = true;
    package = pkgs.zellij;
    enableBashIntegration = false;
    enableZshIntegration = false;
    enableFishIntegration = false;
    extraConfig = builtins.readFile ./config.kdl;
  };
  catppuccin.zellij.enable = true;

  # home.shellAliases 在 nushell 不生效，因此这里额外同步一份别名。
  home.shellAliases = shellAliases;
  programs.nushell.shellAliases = shellAliases;
}
