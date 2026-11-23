{
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    inherit (pkgs) lib;
    # GitHub Release API 的下载计数会变化，直接固定发布文件的校验值。
    version = "1.5.3";
    releaseAssets = {
      x86_64-linux = {
        target = "linux-amd64";
        hash = "sha256-u1LKpNPGAc+kHuznWBliNCPOAqjdVUd5kTBAqUP/81g=";
      };
      aarch64-linux = {
        target = "linux-arm64";
        hash = "sha256-sIEEqD/QBavQDDtfdF7wt2kNWmHycRtJsKFwOBXOnhg=";
      };
      x86_64-darwin = {
        target = "darwin-amd64";
        hash = "sha256-bophXPAbDMZMChp4UsxV3d5P+sQI/itD5nrChdjyRCw=";
      };
      aarch64-darwin = {
        target = "darwin-arm64";
        hash = "sha256-o7waerOKzW+83bBav2bDjxlcS8Ep7NfJ/yN4l6aWUVk=";
      };
    };
    asset = releaseAssets.${system};
    assetName = "cc-connect-v${version}-${asset.target}";
  in {
    packages = lib.optionalAttrs (builtins.hasAttr system releaseAssets) {
      cc-connect = pkgs.stdenvNoCC.mkDerivation {
        pname = "cc-connect";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://github.com/chenhg5/cc-connect/releases/download/v${version}/${assetName}.tar.gz";
          inherit (asset) hash;
        };
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
          platforms = builtins.attrNames releaseAssets;
        };
      };
    };
  };
}
