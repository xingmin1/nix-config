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
  };
  xdg.configFile."zellij/config.kdl".source = ./config.kdl;
  # 为避免与非 Nix 的本地配置冲突，这里不启用 catppuccin。
  # catppuccin.zellij.enable = false;

  # home.shellAliases 在 nushell 不生效，因此这里额外同步一份别名。
  home.shellAliases = shellAliases;
  programs.nushell.shellAliases = shellAliases;
}
