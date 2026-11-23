{
  lib,
  stdenvNoCC,
  stdenv,
  fetchurl,
  releaseChecksums,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  fontconfig,
  freetype,
  libxcb,
  libxkbcommon,
  vulkan-loader,
  wayland,
  wl-clipboard,
  xclip,
}: let
  arch = stdenvNoCC.hostPlatform.parsed.cpu.name;
  assets = lib.filter (match: match != null) (map
    (line: builtins.match "([0-9a-fA-F]{64})[[:blank:]]+\\*?(Sheprd-([0-9][0-9A-Za-z.+-]*)-${arch}-unknown-linux-gnu\\.deb)" line)
    (lib.splitString "\n" (builtins.readFile releaseChecksums)));
  asset =
    if builtins.length assets == 1
    then builtins.head assets
    else throw "Sheprd 校验清单中必须恰好有一个 Linux ${arch} 桌面包";
  assetName = builtins.elemAt asset 1;
  version = builtins.elemAt asset 2;
in
  stdenvNoCC.mkDerivation {
    pname = "sheprd";
    inherit version;
    src = fetchurl {
      url = "https://github.com/sheprd-labs/sheprd/releases/download/v${version}/${assetName}";
      hash = builtins.convertHash {
        hash = builtins.elemAt asset 0;
        hashAlgo = "sha256";
        toHashFormat = "sri";
      };
    };

    nativeBuildInputs = [dpkg autoPatchelfHook makeWrapper];
    buildInputs = [stdenv.cc.cc.lib alsa-lib libxcb libxkbcommon];
    runtimeDependencies = [fontconfig freetype vulkan-loader wayland];
    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x "$src" .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      # 保留发布包内辅助程序和 herdr-core 的相对位置。
      mkdir -p "$out/libexec/sheprd"
      cp -a usr/bin/. "$out/libexec/sheprd/"
      cp -r usr/share "$out/share"
      makeWrapper "$out/libexec/sheprd/sheprd" "$out/bin/sheprd" \
        --prefix PATH : "$out/libexec/sheprd:${lib.makeBinPath [wl-clipboard xclip]}"
      runHook postInstall
    '';

    meta = {
      description = "Native desktop client for Herdr and herdr-core";
      homepage = "https://github.com/sheprd-labs/sheprd";
      license = lib.licenses.asl20;
      mainProgram = "sheprd";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
