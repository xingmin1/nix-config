{
  flake,
  pkgs,
  ...
}:
{
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

      # python
      (python313.withPackages (
        ps: with ps; [
          # python language server
          pyright
          ruff

          pipx # Install and Run Python Applications in Isolated Environments
          black # python formatter
          uv # python project package manager
        ]
      ))

      # c
      clang-tools
      cmake

    ])
    ++ (with flake.inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}; [
      codex
      opencode
    ]);

  # Programs natively supported by home-manager.
  # They can be configured in `programs.*` instead of using home.packages.
  programs = {
    # Better `cat`
    bat.enable = true;
    # Type `<ctrl> + r` to fuzzy search your shell history
    fzf.enable = true;
    jq.enable = true;
    # Install btop https://github.com/aristocratos/btop
    btop.enable = true;
    # Tmate terminal sharing.
    tmate = {
      enable = true;
      #host = ""; #In case you wish to use a server other than tmate.io
    };
  };
}
