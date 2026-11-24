{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  procps,
  xz,
}: let
  version = "7.0.0";
  releases = {
    x86_64-linux = {
      arch = "x64";
      hash = "sha256-MAZy4vvgMAR9LMGnt1WyAD3NkjyQdF3xQoxTdIZY1AA=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-VljdMCfK9gVJOYWKQQW13lOY3xasUAtYcaMPN1Izryw=";
    };
  };
  release = releases.${stdenv.hostPlatform.system};
in
  stdenv.mkDerivation {
    pname = "weflow";
    inherit version;

    # 采用固定版本的官方二进制，同步核对发布页的 SHA-256 清单。
    src = fetchurl {
      url = "https://github.com/334456777/WeFlow/releases/download/v${version}/weflow-v${version}-linux-${release.arch}.tar.gz";
      inherit (release) hash;
    };
    nativeBuildInputs = [autoPatchelfHook makeWrapper];
    buildInputs = [stdenv.cc.cc.lib xz];
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 weflow "$out/bin/weflow"
      install -Dm644 LICENSE "$out/share/licenses/weflow/LICENSE"
      wrapProgram "$out/bin/weflow" --prefix PATH : "${lib.makeBinPath [procps]}"
      runHook postInstall
    '';

    meta = {
      description = "WeChat local archive tool";
      homepage = "https://github.com/334456777/WeFlow";
      license = lib.licenses.unlicense;
      mainProgram = "weflow";
      platforms = builtins.attrNames releases;
    };
  }
