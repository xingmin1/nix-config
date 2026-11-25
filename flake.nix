{
  description = "A home-manager template providing useful tools & settings for Nix-based development";

  nixConfig = {
    extra-substituters = ["https://cache.numtide.com"];
    extra-trusted-public-keys = ["niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="];
  };

  inputs = {
    # Principle inputs (updated by `nix run .#update`)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-unified.url = "github:srid/nixos-unified";

    # Software inputs
    wetypex = {
      url = "github:panxuc/fcitx5-wetypex";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    vertex.url = "github:juspay/vertex";
    llm-agents.url = "github:numtide/llm-agents.nix";
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # 临时锁定到 4.5.0。2026-11-25 上游 ast-bro 4.7.0 缺少
    # src/installers/pi_extension.ts，导致 ast-bro-4.7.0.drv 构建失败。
    # 上游补齐文件并恢复构建后，可解除此版本锁定。
    ast-bro = {
      url = "github:aeroxy/ast-bro/4.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    favnyr.url = "github:GlitchAwakened/Favnyr/33e0e446d7a0dec43d3bfacd295abfae4b87afeb?dir=packaging/nix";
    # 通过 latest 资产在更新锁文件时跟进上游发布。
    jcodeLinuxX64 = {
      type = "file";
      url = "https://github.com/1jehuang/jcode/releases/latest/download/jcode-linux-x86_64.tar.gz";
      flake = false;
    };
    codexForkLinuxX64 = {
      type = "file";
      url = "https://github.com/xingmin1/codex/releases/latest/download/codex-package-x86_64-unknown-linux-musl.tar.gz";
      flake = false;
    };
    # codex2api 的资产名内嵌版本号，故锁定同样无版本名的校验文件，
    # 模块从其中同时取出版本号与资产哈希。
    codex2apiChecksums = {
      type = "file";
      url = "https://github.com/xingmin1/codex2api/releases/latest/download/SHA256SUMS.txt";
      flake = false;
    };
    # 固定到当前已验证的 ArcMD 发布，避免 latest 变动让锁定的校验清单失效。
    arcmdChecksums = {
      type = "file";
      url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.2.5/SHA256SUMS.txt";
      flake = false;
    };
    ghelper = {
      url = "github:utajum/g-helper-linux?dir=nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    krunnerPinyinSrc = {
      url = "github:AOSC-Dev/krunner-pinyin-search";
      flake = false;
    };
    uuRemoteLinuxRelease = {
      type = "file";
      # 固定已安装版本，避免最新发布变化时原锁文件无法重新构建。
      url = "https://api.github.com/repos/VallierDev/uu-remote-linux/releases/tags/v0.2.62";
      flake = false;
    };
    sheprdChecksums = {
      type = "file";
      # 固定已安装版本的校验清单，避免发布新版时旧配置无法重建。
      url = "https://github.com/sheprd-labs/sheprd/releases/download/v20261118.1/SHA256SUMS";
      flake = false;
    };
    # Slack CLI 在每个 Release 里都附带无版本名的 latest 别名资产。
    slackCliLinuxAmd64 = {
      type = "file";
      url = "https://github.com/slackapi/slack-cli/releases/latest/download/slack_cli_latest_linux_amd64.tar.gz";
      flake = false;
    };
    slackCliLinuxArm64 = {
      type = "file";
      url = "https://github.com/slackapi/slack-cli/releases/latest/download/slack_cli_latest_linux_arm64.tar.gz";
      flake = false;
    };
    slackCliMacosAmd64 = {
      type = "file";
      url = "https://github.com/slackapi/slack-cli/releases/latest/download/slack_cli_latest_macOS_amd64.tar.gz";
      flake = false;
    };
    slackCliMacosArm64 = {
      type = "file";
      url = "https://github.com/slackapi/slack-cli/releases/latest/download/slack_cli_latest_macOS_arm64.tar.gz";
      flake = false;
    };
    openGrokLinuxX64 = {
      type = "file";
      url = "https://github.com/mweinbach/open-grok/releases/latest/download/open-grok-linux-x86_64";
      flake = false;
    };
    openGrokLinuxAarch64 = {
      type = "file";
      url = "https://github.com/mweinbach/open-grok/releases/latest/download/open-grok-linux-aarch64";
      flake = false;
    };
    # OMP 官方预编译二进制；更新锁文件时跟随最新 Release。
    ompLinuxX64 = {
      type = "file";
      url = "https://github.com/can1357/oh-my-pi/releases/latest/download/omp-linux-x64";
      flake = false;
    };
    ompLinuxAarch64 = {
      type = "file";
      url = "https://github.com/can1357/oh-my-pi/releases/latest/download/omp-linux-arm64";
      flake = false;
    };
    # 锁定更新时解析最新 Release，常规系统构建仍使用 flake.lock 中固定的二进制。
    tftpNowBinary = {
      type = "file";
      url = "https://github.com/puhitaku/tftp-now/releases/latest/download/tftp-now-linux-amd64";
      flake = false;
    };
    magpieRelease = {
      type = "file";
      url = "https://api.github.com/repos/yetone/magpie/releases/tags/v0.1.4634";
      flake = false;
    };
    officecliRelease = {
      type = "file";
      url = "https://api.github.com/repos/iOfficeAI/OfficeCLI/releases/latest";
      flake = false;
    };
    nbCliRelease = {
      type = "file";
      url = "https://api.github.com/repos/jupyter-ai-contrib/nb-cli/releases/latest";
      flake = false;
    };
    justLspRelease = {
      type = "file";
      url = "https://api.github.com/repos/terror/just-lsp/releases/latest";
      flake = false;
    };
    genofficeRelease = {
      type = "file";
      url = "https://api.github.com/repos/genspark-ai/genoffice/releases/latest";
      flake = false;
    };
    officecliSkills = {
      url = "github:iOfficeAI/OfficeCLI";
      flake = false;
    };
    nbCliSkills = {
      url = "github:jupyter-ai-contrib/nb-cli";
      flake = false;
    };
    manPagesZhSrc = {
      url = "github:man-pages-zh/manpages-zh";
      flake = false;
    };
    magpieIcon = {
      type = "file";
      url = "https://raw.githubusercontent.com/yetone/magpie/HEAD/internal/gui/icon-256.png";
      flake = false;
    };
    genofficeNpmLock = {
      type = "file";
      url = "https://raw.githubusercontent.com/genspark-ai/genoffice/HEAD/package-lock.json";
      flake = false;
    };
    # https://github.com/catppuccin/nix
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # 上游发布流程会把版本与各平台资产的 url/sha256 写进仓库的
    # packaging/nix/sources.json，因此锁定其 Git 仓库即可跟随最新 Release，
    # 且锁的是不可变提交内容，不会再被动态字段击穿哈希校验。
    collieRepo = {
      url = "github:AltanS/collie";
      flake = false;
    };
  };

  # Wired using https://nixos-unified.org/autowiring.html
  outputs = inputs:
    inputs.nixos-unified.lib.mkFlake {
      inherit inputs;
      root = ./.;
    };
}
