{
  description = "A home-manager template providing useful tools & settings for Nix-based development";

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
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    vertex.url = "github:juspay/vertex";
    llm-agents.url = "github:numtide/llm-agents.nix";
    # 通过 GitHub latest release 固定自定义 Codex 的版本元数据。
    # 构建时会从锁定的 release JSON 中选择当前平台的预编译压缩包。
    codexLatestRelease = {
      type = "file";
      url = "https://api.github.com/repos/xingmin1/codex/releases/latest";
      flake = false;
    };
    # 通过 GitHub latest release 固定 codex2api 的版本元数据。
    # 构建时会从锁定的 release JSON 中选择当前平台的预编译压缩包。
    codex2apiLatestRelease = {
      type = "file";
      url = "https://api.github.com/repos/xingmin1/codex2api/releases/latest";
      flake = false;
    };
    # 通过 npm beta dist-tag 固定当前可用的 cc-connect beta 元数据。
    # 以后只需要 `nix flake update`，flake.lock 就会推进这里的版本信息。
    ccConnectBeta = {
      type = "file";
      url = "https://registry.npmjs.org/cc-connect/beta";
      flake = false;
    };
    # https://github.com/catppuccin/nix
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Wired using https://nixos-unified.org/autowiring.html
  outputs = inputs:
    inputs.nixos-unified.lib.mkFlake {
      inherit inputs;
      root = ./.;
    };
}
