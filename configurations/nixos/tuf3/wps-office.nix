{
  lib,
  libxcursor,
  makeWrapper,
  noto-fonts-cjk-sans,
  symlinkJoin,
  wpsoffice-cn,
  writeText,
}: let
  staticNotoSansCjk = noto-fonts-cjk-sans.override {static = true;};
  wpsFontConfig = writeText "wps-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include>/etc/fonts/fonts.conf</include>
      <dir>${staticNotoSansCjk}/share/fonts/opentype/noto-cjk</dir>
      <selectfont>
        <rejectfont>
          <glob>*/NotoSansCJK-VF.otf.ttc</glob>
        </rejectfont>
      </selectfont>
    </fontconfig>
  '';
in
  symlinkJoin {
    name = "wpsoffice-cn-desktop-${wpsoffice-cn.version}";
    paths = [wpsoffice-cn];
    nativeBuildInputs = [makeWrapper];
    inherit (wpsoffice-cn) meta;
    postBuild = ''
      # 随 WPS 分发的 Qt 5.12 无法正确渲染 Noto CJK 可变字重。
      # XCB 按需加载 Xcursor，缺库时会回退到很小的 X11 指针。
      # WPS 自带 Qt 5.12，并随包提供匹配的 Fcitx 平台插件。
      # WPS 在 KDE Wayland 下通过 XWayland 运行，使用该插件接入 Fcitx5。
      for app in wps et wpp wpspdf; do
        wrapProgram "$out/bin/$app" \
          --set-default FONTCONFIG_FILE "${wpsFontConfig}" \
          --set QT_IM_MODULE fcitx \
          --set GTK_IM_MODULE fcitx \
          --set XMODIFIERS "@im=fcitx" \
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [libxcursor]}"
      done
      for desktop in "${wpsoffice-cn}"/share/applications/wps-office-*.desktop; do
        name=$(basename "$desktop")
        sed -E "s@^Exec=(wps|et|wpp|wpspdf)( |$)@Exec=$out/bin/\1\2@" "$desktop" > "$TMPDIR/$name"
        cp --remove-destination "$TMPDIR/$name" "$out/share/applications/$name"
      done
    '';
  }
