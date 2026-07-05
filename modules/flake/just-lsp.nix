{...}: {
  perSystem = {pkgs, ...}: {
    packages.just-lsp = pkgs.rustPlatform.buildRustPackage rec {
      pname = "just-lsp";
      version = "0.4.7";

      src = pkgs.fetchCrate {
        inherit pname version;
        hash = "sha256-qRRn9Po7s3jId7Ymd+rhdPwmzFsRZJT6dg0/WwWFZdw=";
      };

      cargoHash = "sha256-LAvRBDMdy8iYYK6wIvdNCf6skUxJoPIx9KJoQcc6ST8=";

      meta = {
        description = "Just language server";
        homepage = "https://github.com/terror/just-lsp";
        license = pkgs.lib.licenses.cc0;
        mainProgram = "just-lsp";
        platforms = pkgs.lib.platforms.unix;
      };
    };
  };
}
