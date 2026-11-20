{
  lib,
  stdenvNoCC,
  fetchurl,
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
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "magpie";
  version = "0.1.4578";

  src = fetchurl {
    url = "https://github.com/yetone/magpie/releases/download/v${finalAttrs.version}/magpie-linux-amd64";
    hash = "sha256-4IgcqEBPoNcrD5OBtj1GZ5nUW/7o7KxwRyjoOC8dqh8=";
  };
  appIcon = fetchurl {
    url = "https://raw.githubusercontent.com/yetone/magpie/v${finalAttrs.version}/internal/gui/icon-256.png";
    hash = "sha256-V0N8ZZbgWo/PxC1CiMAwqgDthraf411GTWnXAmFQxwQ=";
  };
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
    install -Dm644 "$appIcon" "$out/share/icons/hicolor/256x256/apps/magpie.png"
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
})
