{
  config,
  flake,
  lib,
  pkgs,
  ...
}: let
  llmAgentPackages = flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  codexSubagentInstructions = "${config.home.homeDirectory}/.codex/instructions/subagents.md";
  configuredCodex = pkgs.symlinkJoin {
    name = "codex-configured";
    paths = [llmAgentPackages.codex];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram "$out/bin/codex" \
        --run 'if [ -r "${codexSubagentInstructions}" ]; then set -- -c "developer_instructions=$(${pkgs.coreutils}/bin/cat "${codexSubagentInstructions}")" "$@"; fi'
    '';
  };
  configuredGrok = pkgs.symlinkJoin {
    name = "grok-configured";
    paths = [flake.inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.grok];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      for program in grok agent; do
        wrapProgram "$out/bin/$program" \
          --add-flags "--always-approve" \
          --set GROK_CODEX2API_KEY local-compat-proxy
      done
    '';
  };
  legacyAgentPackages = lib.optionals (!pkgs.stdenv.isLinux) (
    (with llmAgentPackages; [
      codex-acp
      claude-code
      omp
    ])
    ++ [
      configuredCodex
      configuredGrok
    ]
  );
  manPagesZh = pkgs.stdenv.mkDerivation {
    pname = "man-pages-zh";
    version = "1.6.4.1-unstable-2026-07-31";

    src = pkgs.fetchFromGitHub {
      owner = "man-pages-zh";
      repo = "manpages-zh";
      rev = "b536c007574c5354e12b883893a5ec89b704dbe0";
      hash = "sha256-dGV//enA1WzGsM1zmvXOqBe4nL+cBrXIf5WieOjzISk=";
    };

    nativeBuildInputs = with pkgs; [
      cmake
      opencc
    ];

    cmakeFlags = [
      "-DENABLE_APPEND_COLOPHON=OFF"
      "-DENABLE_ZHCN=ON"
      "-DENABLE_ZHTW=OFF"
    ];
  };
  naviPackage = pkgs.navi;
  naviCheatsConfig = "${config.xdg.configHome}/navi/cheats";
  naviCheatsData = "${config.xdg.dataHome}/navi/cheats";
  selfPackages = flake.inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in {
  # Nix packages to install to $HOME
  #
  # Search for packages here: https://search.nixos.org/packages
  home.packages =
    (with pkgs; [
      # omnix

      # Unix tools
      ripgrep # Better `grep`
      ast-grep # 按文本内容找
      fd
      sd
      tree
      gnumake
      file
      just
      tokei
      procs
      below
      lsof

      # Nix dev
      cachix
      nil # Nix language server
      nixd # Nix language server
      nix-info
      nixpkgs-fmt
      nixfmt-rfc-style
      # flake.inputs.alejandra.defaultPackage.${pkgs.stdenv.hostPlatform.system}
      alejandra

      # config language
      taplo # TOML language server / formatter / validator

      # On ubuntu, we need this less for `man home-configuration.nix`'s pager to
      # work.
      less

      nodejs
      bun

      # Python 工具
      uv # Python 项目与 CLI 工具管理器
      (python313.withPackages (
        ps:
          with ps; [
            # Python 语言服务与格式化
            pyright
            ruff

            black
          ]
      ))

      # c
      clang-tools
      cmake

      # 嵌入式与硬件开发
      usbutils
      tio
      picocom
      serial-studio
      pulseview
      sigrok-cli
      openocd
      probe-rs-tools

      typst
      touying
      ouch

      # 磁盘、文件系统与虚拟化工具
      util-linux
      e2fsprogs
      qemu
      parted
      gptfdisk
      libguestfs

      # 中英文系统手册页
      man
      man-pages
      manPagesZh

      tlrc

      maple-mono.NF-CN-unhinted
      source-han-serif
    ])
    ++ (with llmAgentPackages; [
      trellis
    ])
    ++ (with selfPackages; [
      cc-connect
      just-lsp
    ])
    ++ lib.optional (builtins.hasAttr "open-grok" selfPackages) selfPackages.open-grok
    ++ legacyAgentPackages;
  # Programs natively supported by home-manager.
  # They can be configured in `programs.*` instead of using home.packages.
  programs = {
    # Better `cat`
    bat.enable = true;
    eza = {
      enable = true;
      colors = "auto";
      git = true;
      icons = "auto";
      enableNushellIntegration = true;
    };
    # Type `<ctrl> + r` to fuzzy search your shell history
    fzf.enable = true;
    jq.enable = true;
    # Install btop https://github.com/aristocratos/btop
    btop.enable = true;
    bottom.enable = true;
    htop.enable = true;

    # Tmate terminal sharing.
    tmate = {
      enable = true;
      #host = ""; #In case you wish to use a server other than tmate.io
    };
    # GitHub CLI
    gh.enable = true;

    navi = {
      enable = true;
      package = naviPackage;

      enableBashIntegration = false;
      enableFishIntegration = false;
      enableZshIntegration = false;

      settings = {
        cheats.paths = [
          naviCheatsConfig
          naviCheatsData
        ];

        finder = {
          command = "fzf";
          overrides = "--height=80% --layout=reverse --border --cycle --ansi --prompt='navi> '";
          overrides_var = "--height=40% --layout=reverse --border --cycle --ansi --prompt='value> '";
          delimiter_var = "\\s\\s+";
        };

        shell = {
          command = "bash";
          finder_command = "bash";
        };

        style = {
          tag = {
            width_percentage = 18;
            min_width = 12;
          };
          comment = {
            width_percentage = 42;
            min_width = 30;
          };
          snippet = {
            width_percentage = 40;
            min_width = 30;
          };
        };
      };
    };
  };

  xdg.configFile."tlrc/config.toml".text = ''
    [cache]
    auto_update = false
    defer_auto_update = true
    max_age = 168
    languages = ["zh"]

    [output]
    show_title = true
    platform_title = true
    show_hyphens = true
    edit_link = false
    example_prefix = "- "
    line_length = 0
    compact = true
    option_style = "long"
    raw_markdown = false

    [indent]
    title = 0
    description = 0
    bullet = 0
    example = 2
  '';

  xdg.configFile."navi/cheats/.keep".text = "";

  home.shellAliases = {
    tl = "tldr -o -L zh -L en";
    nt = "navi --tldr";
    nsh = "navi --cheatsh";
    top = "btop";
    ps = "procs";
  };

  programs.bash.initExtra = lib.mkAfter ''
    if [[ :$SHELLOPTS: =~ :(vi|emacs): ]]; then
      eval "$(${lib.getExe naviPackage} widget bash | sed 's/\\C-g/\\C-n/g')"
    fi
  '';

  programs.fish.interactiveShellInit = lib.mkAfter ''
    ${lib.getExe naviPackage} widget fish | string replace --all '\cg' '\cn' | source
  '';

  programs.zsh.initContent = lib.mkAfter ''
    if [[ $options[zle] = on ]]; then
      eval "$(${lib.getExe naviPackage} widget zsh | sed "s/bindkey '\^g'/bindkey '\^N'/")"

      bindkey -M emacs '^N' _navi_widget 2>/dev/null || true
      bindkey -M viins '^N' _navi_widget 2>/dev/null || true
    fi
  '';
}
