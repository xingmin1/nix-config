{
  lib,
  stdenvNoCC,
  fetchurl,
  releaseMetadata,
  appIcon,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  wrapGAppsHook3,
  fontconfig,
  gdk-pixbuf,
  glib,
  glib-networking,
  gsettings-desktop-schemas,
  gtk3,
  libsoup_3,
  libx11,
  wayland,
  webkitgtk_4_1,
}: let
  release = import ../../../lib/github-release.nix {
    inherit lib fetchurl;
    metadata = releaseMetadata;
  };
in
  stdenvNoCC.mkDerivation {
    pname = "magpie";
    inherit (release) version;
    src = release.asset "magpie-linux-amd64";
    dontUnpack = true;

    nativeBuildInputs = [
      autoPatchelfHook
      copyDesktopItems
      wrapGAppsHook3
    ];

    buildInputs = [
      fontconfig
      gdk-pixbuf
      glib
      glib-networking
      gsettings-desktop-schemas
      gtk3
      libsoup_3
      libx11
      wayland
      webkitgtk_4_1
    ];

    preFixup = ''
      # 使用实测更流畅的 WebKitGTK 硬件渲染路径。
      gappsWrapperArgs+=(
        --set-default GDK_BACKEND wayland,x11
        --set-default WEBKIT_DISABLE_COMPOSITING_MODE 0
        --set-default WEBKIT_DISABLE_DMABUF_RENDERER 0
      )
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "magpie";
        desktopName = "Magpie";
        comment = "Manage AI agents and model providers";
        exec = "magpie %u";
        icon = "magpie";
        startupWMClass = "magpie";
        mimeTypes = ["x-scheme-handler/magpie"];
        categories = ["Development" "Utility"];
      })
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/magpie"
      install -Dm644 ${appIcon} "$out/share/icons/hicolor/256x256/apps/magpie.png"
      runHook postInstall
    '';

    postFixup = ''
      substituteInPlace "$out/share/applications/magpie.desktop" \
        --replace-fail 'Exec=magpie ' "Exec=$out/bin/magpie "
    '';

    meta = {
      description = "Desktop application for managing AI agents and model providers";
      homepage = "https://github.com/yetone/magpie";
      license = lib.licenses.mit;
      mainProgram = "magpie";
      platforms = ["x86_64-linux"];
    };
  }
