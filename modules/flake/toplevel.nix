# Top-level flake glue to get our configuration working
{inputs, ...}: {
  imports = [
    inputs.nixos-unified.flakeModules.default
    inputs.nixos-unified.flakeModules.autoWire
  ];
  perSystem = {
    self',
    pkgs,
    ...
  }: {
    # For 'nix fmt'
    formatter = pkgs.writeShellApplication {
      name = "nix-config-fmt";
      runtimeInputs = [
        pkgs.alejandra
        pkgs.fd
        pkgs.findutils
      ];
      text = ''
        if [ "$#" -gt 0 ]; then
          alejandra "$@"
          exit
        fi

        fd --hidden \
          --exclude .git \
          --exclude .jj \
          --exclude .direnv \
          --exclude result \
          --extension nix \
          --type f \
          --print0 \
          | xargs -0 -r alejandra
      '';
    };

    # Enables 'nix run' to activate.
    packages.default = self'.packages.activate;
  };
}
