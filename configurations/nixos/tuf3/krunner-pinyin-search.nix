{
  lib,
  stdenv,
  cmake,
  pkg-config,
  kdePackages,
  libpinyin,
  src,
}:
stdenv.mkDerivation {
  pname = "krunner-pinyin-search";
  version = "unstable-${src.shortRev}";
  inherit src;

  nativeBuildInputs = [cmake pkg-config kdePackages.extra-cmake-modules];
  buildInputs = with kdePackages; [qtbase krunner ki18n kservice kio kcoreaddons kjobwidgets libpinyin];
  cmakeFlags = ["-DKDE_INSTALL_PLUGINDIR=${kdePackages.qtbase.qtPluginPrefix}"];
  dontWrapQtApps = true;

  meta = {
    description = "Search for applications in KRunner by Chinese pinyin";
    homepage = "https://github.com/AOSC-Dev/krunner-pinyin-search";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.linux;
  };
}
