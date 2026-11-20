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
  configuredDsh = pkgs.symlinkJoin {
    name = "dsh-configured";
    paths = [llmAgentPackages.dsh];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram "$out/bin/dsh" \
        --prefix PATH : ${lib.makeBinPath [pkgs.pnpm]}
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
    version = "unstable-${flake.inputs.manPagesZhSrc.shortRev}";
    src = flake.inputs.manPagesZhSrc;

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
      repomix
      procs
      (below.overrideAttrs (old: {
        buildInputs = (old.buildInputs or []) ++ [zstd];
      }))
      lsof
      mosh

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
      pnpm_10
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
      # Nix store 中的安装布局未被 Slidev 识别，且不能用于写入 Vite 缓存。
      (slidev-cli.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace packages/slidev/node/resolver.ts \
            --replace-fail "|| (await import('is-installed-globally')).default" "|| true"
          substituteInPlace packages/slidev/node/vite/extendConfig.ts \
            --replace-fail "cacheDir: isInstalledGlobally.value ? join(options.cliRoot, 'node_modules/.vite') : undefined," "cacheDir: undefined,"
        '';
      }))
      ouch

      # 视频分析与转码
      ffmpeg

      # 磁盘、文件系统与虚拟化工具
      util-linux
      e2fsprogs
      qemu
      parted
      gptfdisk

      # 中英文系统手册页
      man
      man-pages
      manPagesZh

      tlrc

      maple-mono.NF-CN-unhinted
      source-han-serif

      # Playwright 浏览器自动化与 CLI
      playwright-test
      (pkgs.writeShellScriptBin "playwright-cli" ''
        export PLAYWRIGHT_BROWSERS_PATH="''${PLAYWRIGHT_BROWSERS_PATH:-${pkgs.playwright-driver.browsers}}"
        export PLAYWRIGHT_MCP_BROWSER="''${PLAYWRIGHT_MCP_BROWSER:-chromium}"
        exec ${pkgs.playwright-test}/bin/playwright cli "$@"
      '')

      # AI Agent 浏览器自动化 CLI (Vercel Labs)
      agent-browser
    ])
    ++ (with llmAgentPackages; [
      trellis
      antigravity-cli
      configuredDsh
      pi
      herdr
      # 直接复用上游原包及其缓存，语言资源已由上游打包。
      hermes-agent
      hermes-desktop
    ])
    ++ (with selfPackages; [
      cc-connect
      collie
      just-lsp
      mineru
      slack-cli-official
    ])
    ++ lib.optional (builtins.hasAttr "omp-release" selfPackages) selfPackages.omp-release
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

    # Tmate terminal sharing（因上游停更且含 CVE-2018-19387，已被 nixpkgs 标记为 insecure，故禁用）
    tmate.enable = false;
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

  # Playwright 与 agent-browser 会话环境变量与全局配置
  home.sessionVariables = {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_MCP_BROWSER = "chromium";
    AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.playwright-driver.browsers}/chromium-1243/chrome-linux64/chrome-wrapper";
  };

  home.file.".playwright/cli.config.json".text = builtins.toJSON {
    browser = {
      browserName = "chromium";
    };
  };
}
