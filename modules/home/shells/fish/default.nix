{
  # 迁移自 khanelinix：Fish 配置（函数、插件与初始化脚本）。
  #
  # 适配说明：
  # - 去除对 fastfetch 的引用，避免未定义选项导致评估失败。
  # - 保留 macOS 条件初始化段，Linux 下不生效。
  config,
  lib,
  pkgs,
  osConfig ? { },

  ...
}:
let
  inherit (lib) mkIf;
in
{
  # 同步 functions 目录（别名、git、cd 等）
  xdg.configFile."fish/functions" = {
    source = lib.cleanSourceWith { src = lib.cleanSource ./functions/.; };
    recursive = true;
  };

  programs.fish = {
    enable = true;

    loginShellInit =
      let
        dquote = str: "\"" + str + "\"";
        makeBinPathList = map (path: path + "/bin");
      in
      lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
        export NIX_PATH="darwin-config=$HOME/.nixpkgs/darwin-configuration.nix:$HOME/.nix-defexpr/channels:$NIX_PATH"
        fish_add_path --move --prepend --path ${
          lib.concatMapStringsSep " " dquote (makeBinPathList (osConfig.environment.profiles or [ ]))
        }
        set fish_user_paths $fish_user_paths
      '';

    interactiveShellInit = ''
      # 1password plugin
      if [ -f ~/.config/op/plugins.sh ]
          source ~/.config/op/plugins.sh
      end

      # Disable greeting
      set fish_greeting
    ''
    + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      # Brew environment
      if [ -f /opt/homebrew/bin/brew ]
      	eval "$("/opt/homebrew/bin/brew" shellenv)"
      end

      # Nix
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish' ]
       source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
      end
      if [ -f '/nix/var/nix/profiles/default/etc/profile.d/nix.fish' ]
       source '/nix/var/nix/profiles/default/etc/profile.d/nix.fish'
      end
      # End Nix
    '';

    plugins = [
      { name = "autopair"; inherit (pkgs.fishPlugins.autopair) src; }
      { name = "done"; inherit (pkgs.fishPlugins.done) src; }
      { name = "fzf-fish"; inherit (pkgs.fishPlugins.fzf-fish) src; }
      { name = "forgit"; inherit (pkgs.fishPlugins.forgit) src; }
      { name = "tide"; inherit (pkgs.fishPlugins.tide) src; }
      { name = "sponge"; inherit (pkgs.fishPlugins.sponge) src; }
      { name = "wakatime"; inherit (pkgs.fishPlugins.wakatime-fish) src; }
      { name = "z"; inherit (pkgs.fishPlugins.z) src; }
    ];
  };
}

