{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;
    release = import ../../lib/github-release.nix {
      inherit lib;
      inherit (pkgs) fetchurl;
      metadata = inputs.justLspRelease;
    };
    inherit (release) version;
    targets = {
      x86_64-linux = "x86_64-unknown-linux-musl";
      aarch64-linux = "aarch64-unknown-linux-musl";
      x86_64-darwin = "x86_64-apple-darwin";
      aarch64-darwin = "aarch64-apple-darwin";
    };
    target = targets.${stdenv.hostPlatform.system} or null;
  in {
    packages = lib.optionalAttrs (target != null) {
      just-lsp = pkgs.stdenvNoCC.mkDerivation {
        pname = "just-lsp";
        inherit version;

        src = release.asset "just-lsp-${release.tag}-${target}.tar.gz";

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
          changelog = "https://github.com/terror/just-lsp/releases/latest";
          license = lib.licenses.cc0;
          mainProgram = "just-lsp";
          platforms = builtins.attrNames targets;
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
  };
}
