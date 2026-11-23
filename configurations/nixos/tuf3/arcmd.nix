{
  lib,
  stdenvNoCC,
  fetchurl,
  releaseChecksums,
  autoPatchelfHook,
  wrapGAppsHook3,
  atk,
  cairo,
  fontconfig,
  gdk-pixbuf,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  gtk-layer-shell,
  harfbuzz,
  libayatana-appindicator,
  libepoxy,
  libsecret,
  pango,
  wayland,
}: let
  releaseArchitectures = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };
  arch = releaseArchitectures.${stdenvNoCC.hostPlatform.system};
  checksumLines = lib.splitString "\n" (builtins.readFile releaseChecksums);
  assetMatches = lib.filter (match: match != null) (map
    (line: builtins.match "([0-9a-fA-F]{64})[[:blank:]]+\\*?(arcmd-([0-9][0-9A-Za-z.+-]*)-linux-${arch}\\.tar\\.gz)" line)
    checksumLines);
  asset =
    if builtins.length assetMatches == 1
    then builtins.head assetMatches
    else throw "ArcMD 校验清单中必须恰好有一个 Linux ${arch} 压缩包";
  assetName = builtins.elemAt asset 1;
  version = builtins.elemAt asset 2;
  runtimeLibraries = [
    atk
    cairo
    fontconfig
    gdk-pixbuf
    glib
    gtk3
    gtk-layer-shell
    harfbuzz
    libayatana-appindicator
    libepoxy
    libsecret
    pango
    wayland
  ];
in
  stdenvNoCC.mkDerivation {
    pname = "arcmd";
    inherit version;

    src = fetchurl {
      url = "https://github.com/Ciao1019/ArcMD/releases/download/v${version}/${assetName}";
      hash = builtins.convertHash {
        hash = builtins.elemAt asset 0;
        hashAlgo = "sha256";
        toHashFormat = "sri";
      };
    };
    sourceRoot = ".";

    nativeBuildInputs = [autoPatchelfHook wrapGAppsHook3];
    buildInputs = [gtk3 gsettings-desktop-schemas];
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 arcmd "$out/bin/arcmd"
      install -Dm644 arcmd.desktop "$out/share/applications/arcmd.desktop"
      # 从 Dock 或其他应用调用 KDE 文件关联时，PATH 可能没有用户软件目录。
      substituteInPlace "$out/share/applications/arcmd.desktop" \
        --replace-fail 'Exec=arcmd ' "Exec=$out/bin/arcmd "
      install -Dm644 arcmd.png "$out/share/pixmaps/arcmd.png"
      install -Dm644 arcmd.xml "$out/share/mime/packages/arcmd.xml"
      install -Dm644 LICENSE "$out/share/licenses/arcmd/LICENSE"
      cp -r third_party "$out/share/licenses/arcmd/"
      runHook postInstall
    '';

    # MyGo 在运行时通过 dlopen 加载 Linux 桌面库。
    preFixup = ''
      gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}")
    '';

    meta = {
      description = "Native Markdown editor with Arc-style spaces";
      homepage = "https://github.com/Ciao1019/ArcMD";
      license = lib.licenses.mit;
      mainProgram = "arcmd";
      platforms = builtins.attrNames releaseArchitectures;
    };
  }
