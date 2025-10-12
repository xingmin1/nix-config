# List of users for darwin or nixos system and their top-level configuration.
{ flake, pkgs, lib, config, ... }:
let
  inherit (flake.inputs) self;
  mapListToAttrs = m: f:
    lib.listToAttrs (map (name: { inherit name; value = f name; }) m);
in
{
  options = {
    myusers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of usernames";
      defaultText = "All users under ./configuration/users are included by default";
      default =
        let
          dirContents = builtins.readDir (self + /configurations/home);
          fileNames = builtins.attrNames dirContents; # Extracts keys: [ "xmin.nix" ]
          regularFiles = builtins.filter (name: dirContents.${name} == "regular") fileNames; # Filters for regular files
          baseNames = map (name: builtins.replaceStrings [ ".nix" ] [ "" ] name) regularFiles; # Removes .nix extension
        in
        baseNames;
    };
  };

  config = {
    # For home-manager to work.
    # https://github.com/nix-community/home-manager/issues/4026#issuecomment-1565487545
    users.users = mapListToAttrs config.myusers (name:
      lib.optionalAttrs pkgs.stdenv.isDarwin
        {
          home = "/Users/${name}";
        } // lib.optionalAttrs pkgs.stdenv.isLinux {
        isNormalUser = true;
      }
    );

    # Enable home-manager for our user
    home-manager.users = mapListToAttrs config.myusers (name: {
      imports = [ (self + /configurations/home/${name}.nix) ];
    });

    # All users can add Nix caches.
    nix.settings.trusted-users = [
      "root"
    ] ++ config.myusers;

    environment.systemPackages = [
      pkgs.wget
    ];

    # 为了可以使用 VSCode 远程开发 see: https://nix-community.github.io/NixOS-WSL/how-to/vscode.html
    programs.nix-ld.enable = true;

    # 为了可以使用 zed 远程开发 see: https://github.com/zed-industries/zed/issues/39710
    wsl.extraBin = [
    { src = "${pkgs.coreutils}/bin/uname"; }
    { src = "${pkgs.coreutils}/bin/mkdir"; }
    { src = "${pkgs.coreutils}/bin/cp"; }
];
  };
}
