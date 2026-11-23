{
  pkgs ? let
    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    nixpkgs = lock.nodes.${lock.nodes.${lock.root}.inputs.nixpkgs}.locked;
  in
    import (builtins.fetchTree nixpkgs).outPath {},
}:
pkgs.mkShell {
  name = "nixos-unified-template-shell";
  meta.description = "Shell environment for modifying this Nix configuration";
  packages = with pkgs; [
    just
    nixd
  ];
}
