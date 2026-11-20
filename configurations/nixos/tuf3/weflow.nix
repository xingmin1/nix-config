{
  lib,
  stdenv,
  fetchurl,
  releaseMetadata,
  autoPatchelfHook,
  xz,
}: let
  architectures = {
    x86_64-linux = "x64";
    aarch64-linux = "arm64";
  };
  release = builtins.fromJSON (builtins.readFile releaseMetadata);
  version = lib.removePrefix "v" release.tag_name;
  arch = architectures.${stdenv.hostPlatform.system};
  assetName = "weflow-${release.tag_name}-linux-${arch}.tar.gz";
  asset = lib.findFirst (item: item.name == assetName) (throw "WeFlow release has no ${assetName}") release.assets;
in
  stdenv.mkDerivation {
    pname = "weflow";
    inherit version;

    src = fetchurl {
      url = asset.browser_download_url;
      hash = builtins.convertHash {
        hash = lib.removePrefix "sha256:" asset.digest;
        hashAlgo = "sha256";
        toHashFormat = "sri";
      };
    };

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [stdenv.cc.cc.lib xz];
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 weflow "$out/bin/weflow"
      install -Dm644 LICENSE "$out/share/licenses/weflow/LICENSE"
      runHook postInstall
    '';

    meta = {
      description = "WeChat local archive tool";
      homepage = "https://github.com/334456777/WeFlow";
      license = lib.licenses.unlicense;
      mainProgram = "weflow";
      platforms = builtins.attrNames architectures;
    };
  }
