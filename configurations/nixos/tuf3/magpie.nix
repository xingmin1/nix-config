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

  desktopItems = [
    (makeDesktopItem {
      name = "magpie";
      desktopName = "Magpie";
      comment = "Manage AI agents and model providers";
      exec = "magpie %u";
      icon = "applications-development";
      startupWMClass = "magpie";
      mimeTypes = ["x-scheme-handler/magpie"];
      categories = ["Development" "Utility"];
    })
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/magpie"
    runHook postInstall
  '';

  meta = {
    description = "Desktop application for managing AI agents and model providers";
    homepage = "https://github.com/yetone/magpie";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = ["x86_64-linux"];
  };
})
