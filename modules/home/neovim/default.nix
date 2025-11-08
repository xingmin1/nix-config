{
  config,
  lib,
  pkgs,
  ...
}:
# AstroNvim 风格的 Neovim 配置模块
# - 使用本仓库中的 `modules/home/neovim/nvim` 作为 nvim 配置目录
let
  shellAliases = {
    v = "nvim";
    vdiff = "nvim -d";
  };
  # 将本地工作副本作为 nvim 配置目录（不进入 Nix store，便于直接编辑与调试）
  configPath = "${config.home.homeDirectory}/nix-config/modules/home/neovim/nvim";

  # 为 nvim 提供编译期/配置期所需的环境变量（mason.nvim 常见需求）
  libPath = lib.makeLibraryPath [pkgs.stdenv.cc.cc pkgs.zlib];
  pcPath = lib.makeSearchPathOutput "dev" "lib/pkgconfig" [pkgs.stdenv.cc.cc pkgs.zlib];

  neovim-joined = pkgs.symlinkJoin {
    name = "neovim-joined";
    paths = [pkgs.neovim];

    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/nvim \
        --set LIBRARY_PATH ${libPath} \
        --set PKG_CONFIG_PATH ${pcPath}
    '';
  };
in {
  # 将 ~/.config/nvim 链接到仓库内的 AstroNvim 配置目录
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink configPath;

  # 安装上游 Neovim 二进制；不使用 programs.neovim（避免生成 init.lua 与我们目录链接冲突）
  # 提供编译工具链，满足 treesitter / telescope-fzf-native / mason.nvim 等插件构建需求
  home.packages =
    (with pkgs; [
      gcc # 提供 cc/gcc，可被 nvim 检测到
      gnumake # 常见 make 构建需求
      pkg-config # 供配置阶段查询依赖
      git # lazy.nvim / mason.nvim 依赖常见
      curl # nvim-treesitter 获取 tarball 常用
      unzip # 某些插件/grammar 使用 zip 分发
    ])
    ++ [
      neovim-joined
    ];

  home.sessionVariables = {
    EDITOR = "nvim";
    # 一些程序优先读取 VISUAL，其次才是 EDITOR
    VISUAL = "nvim";
  };

  # 常用别名（兼容 nushell 与 bash/zsh）
  home.shellAliases =
    shellAliases
    // {
      vi = "nvim";
      vim = "nvim";
    };
  programs.nushell.shellAliases = shellAliases;
}
