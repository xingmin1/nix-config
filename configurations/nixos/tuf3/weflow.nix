{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  xz,
}: let
  architectures = {
    x86_64-linux = "x64";
    aarch64-linux = "arm64";
  };
  release = builtins.fromJSON (builtins.readFile ./weflow-release.json);
  inherit (release) tag;
  version = lib.removePrefix "v" tag;
  arch = architectures.${stdenv.hostPlatform.system};
  assetName = "weflow-${tag}-linux-${arch}.tar.gz";
in
  stdenv.mkDerivation {
    pname = "weflow";
    inherit version;

    src = fetchurl {
      url = "https://github.com/334456777/WeFlow/releases/download/${tag}/${assetName}";
      hash = builtins.convertHash {
        hash = release.sha256.${arch};
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
