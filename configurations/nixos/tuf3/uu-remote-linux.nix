{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  releaseMetadata,
  autoPatchelfHook,
  wrapGAppsHook3,
  ffmpeg,
  gtk3,
  glib-networking,
  gsettings-desktop-schemas,
  libx11,
  libxext,
  libxfixes,
  libxtst,
  libei,
  libxkbcommon,
  pipewire,
  sdl2-compat,
  wayland,
  wl-clipboard,
}: let
  release = builtins.fromJSON (builtins.readFile releaseMetadata);
  tag = release.tag_name;
  version = lib.removePrefix "v" tag;
  arch = stdenv.hostPlatform.parsed.cpu.name;
  assetName = "uu-remote-linux-${tag}-${arch}-linux.tar.gz";
  asset = lib.findFirst (item: item.name == assetName) (throw "UU Remote release has no ${assetName}") release.assets;
in
  stdenvNoCC.mkDerivation {
    pname = "uu-remote-linux";
    inherit version;
    src = fetchurl {
      url = asset.browser_download_url;
      hash = builtins.convertHash {
        hash = lib.removePrefix "sha256:" asset.digest;
        hashAlgo = "sha256";
        toHashFormat = "sri";
      };
    };

    nativeBuildInputs = [autoPatchelfHook wrapGAppsHook3];
    buildInputs = [
      stdenv.cc.cc.lib
      gtk3
      glib-networking
      gsettings-desktop-schemas
      libx11
      libxext
      libxfixes
      libxtst
      libei
      libxkbcommon
      pipewire
      sdl2-compat
      wayland
    ];
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      desktopDir="packaging/common/desktop"
      if [ ! -d "$desktopDir" ]; then
        desktopDir="contrib/desktop"
      fi
      install -Dm755 uuremote-server "$out/bin/uuremote-server"
      install -Dm755 uuremote-viewer "$out/bin/uuremote-viewer"
      install -Dm644 -t "$out/lib/uu-remote-linux" libuu-portal.so libuu-wayland.so
      install -Dm644 -t "$out/share/applications" "$desktopDir"/*.desktop
      install -Dm644 "$desktopDir/uu-remote-linux.svg" "$out/share/icons/hicolor/scalable/apps/uu-remote-linux.svg"
      install -Dm644 LICENSE "$out/share/licenses/uu-remote-linux/LICENSE"

      # 由主机启动器或控制端设置按需启动服务。
      mkdir -p "$out/share/systemd/user"
      cat > "$out/share/systemd/user/uuremote-native.service" <<EOF
      [Unit]
      Description=UU Remote Linux host
      After=graphical-session.target
      PartOf=graphical-session.target

      [Service]
      ExecStart=$out/bin/uuremote-server
      Restart=on-failure
      RestartSec=5

      [Install]
      WantedBy=graphical-session.target
      EOF

      substituteInPlace "$out/share/applications/"*.desktop \
        --replace-fail 'Exec=uuremote-' "Exec=$out/bin/uuremote-"
      runHook postInstall
    '';

    preFixup = ''
      gappsWrapperArgs+=(--prefix PATH : "${lib.makeBinPath [ffmpeg wl-clipboard]}")
    '';

    meta = {
      description = "Unofficial NetEase UU Remote host and viewer for Linux";
      homepage = "https://github.com/VallierDev/uu-remote-linux";
      license = lib.licenses.gpl3Only;
      mainProgram = "uuremote-viewer";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
