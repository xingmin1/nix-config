{...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;
    version = "0.10.0";
    assets = {
      x86_64-linux = {
        target = "x86_64-unknown-linux-musl";
        hash = "sha256-PDXhDnbbbMGTFJW7Or2u8CV26utAbCF0IPT9N+Hr4iw=";
      };
      aarch64-linux = {
        target = "aarch64-unknown-linux-musl";
        hash = "sha256-iNg+G/sp9c9Bvh1AVtVjEbzcrYGuxXt3N83ZgUdUdHg=";
      };
      x86_64-darwin = {
        target = "x86_64-apple-darwin";
        hash = "sha256-sXe/snHax86eGB8G6D1h7ch9674FrlDyf4wvtArI7JU=";
      };
      aarch64-darwin = {
        target = "aarch64-apple-darwin";
        hash = "sha256-7spSx9ohtbBPBZpeI7mVdfd6ubRIvbhJEfaxhdOG6cQ=";
      };
    };
    asset = assets.${stdenv.hostPlatform.system} or null;
  in {
    packages = lib.optionalAttrs (asset != null) {
      just-lsp = pkgs.stdenvNoCC.mkDerivation {
        pname = "just-lsp";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://github.com/terror/just-lsp/releases/download/${version}/just-lsp-${version}-${asset.target}.tar.gz";
          inherit (asset) hash;
        };

        # Linux 使用官方静态 musl 二进制，不受系统编译工具链更新影响。
        dontConfigure = true;
        dontBuild = true;
        dontStrip = true;
        sourceRoot = ".";

        installPhase = ''
          runHook preInstall
          install -Dm755 just-lsp "$out/bin/just-lsp"
          install -Dm644 LICENSE "$out/share/licenses/just-lsp/LICENSE"
          install -Dm644 README.md "$out/share/doc/just-lsp/README.md"
          runHook postInstall
        '';

        meta = {
          description = "Just 语言服务器的官方预编译版本";
          homepage = "https://github.com/terror/just-lsp";
          changelog = "https://github.com/terror/just-lsp/releases/tag/${version}";
          license = lib.licenses.cc0;
          mainProgram = "just-lsp";
          platforms = builtins.attrNames assets;
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
  };
}
