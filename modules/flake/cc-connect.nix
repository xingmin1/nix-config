{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    inherit (pkgs) lib;
    release = import ../../lib/github-release.nix {
      inherit lib;
      inherit (pkgs) fetchurl;
      metadata = inputs.ccConnectRelease;
    };
    platforms = {
      x86_64-linux = "linux-amd64";
      aarch64-linux = "linux-arm64";
      x86_64-darwin = "darwin-amd64";
      aarch64-darwin = "darwin-arm64";
    };
    assetName = "cc-connect-${release.tag}-${platforms.${system}}";
  in {
    packages = lib.optionalAttrs (builtins.hasAttr system platforms) {
      cc-connect = pkgs.stdenvNoCC.mkDerivation {
        pname = "cc-connect";
        inherit (release) version;

        src = release.asset "${assetName}.tar.gz";
        sourceRoot = ".";
        dontStrip = true;

        installPhase = ''
          runHook preInstall
          install -Dm755 ${assetName} "$out/bin/cc-connect"
          runHook postInstall
        '';

        meta = {
          description = "Bridge chat platforms to coding agents";
          homepage = "https://github.com/chenhg5/cc-connect";
          license = lib.licenses.mit;
          mainProgram = "cc-connect";
          platforms = builtins.attrNames platforms;
        };
      };
    };
  };
}
