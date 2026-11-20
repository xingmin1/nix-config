{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;
    release = import ../../lib/github-release.nix {
      inherit lib;
      inherit (pkgs) fetchurl;
      metadata = inputs.genofficeRelease;
    };
    inherit (release) version;

    # 补齐上游 Linux 包中缺少的 jsdom 运行依赖。
    upstreamLock = builtins.fromJSON (builtins.readFile inputs.genofficeNpmLock);
    jsdomClosure = builtins.genericClosure {
      startSet = [{key = "node_modules/jsdom";}];
      operator = {key}: let
        package = upstreamLock.packages.${key};
        dependencies = (package.dependencies or {}) // (package.optionalDependencies or {});
      in
        map (name: {
          key =
            if builtins.hasAttr "${key}/node_modules/${name}" upstreamLock.packages
            then "${key}/node_modules/${name}"
            else "node_modules/${name}";
        }) (builtins.attrNames dependencies);
    };
    jsdomModules = pkgs.runCommand "genoffice-${version}-runtime-modules" {} (
      lib.concatMapStringsSep "\n" ({key}: let
        package = upstreamLock.packages.${key};
        archive = pkgs.fetchurl {
          url = package.resolved;
          hash = package.integrity;
        };
      in ''
        mkdir -p "$out/${key}"
        tar -xzf ${archive} --strip-components=1 -C "$out/${key}"
      '')
      jsdomClosure
    );
  in {
    packages = lib.optionalAttrs (stdenv.hostPlatform.system == "x86_64-linux") {
      genoffice = pkgs.stdenvNoCC.mkDerivation {
        pname = "genoffice";
        inherit version;
        src = release.asset "genoffice_${version}_amd64.deb";

        nativeBuildInputs = with pkgs; [
          dpkg
          autoPatchelfHook
          makeWrapper
          wrapGAppsHook3
        ];
        buildInputs = with pkgs; [
          alsa-lib
          at-spi2-core
          cairo
          cups
          dbus
          expat
          fontconfig
          gdk-pixbuf
          glib
          gtk3
          libdrm
          libgbm
          libxkbcommon
          nspr
          nss
          pango
          stdenv.cc.cc.lib
          systemd
          xorg.libX11
          xorg.libxcb
          xorg.libXcomposite
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
          xorg.libXrandr
        ];
        # Electron/ANGLE 通过 dlopen 加载这些库，不能只依赖 DT_NEEDED 自动探测。
        runtimeDependencies = with pkgs; [
          (lib.getLib libGL)
          (lib.getLib vulkan-loader)
          (lib.getLib libnotify)
          (lib.getLib libsecret)
          (lib.getLib libpulseaudio)
          (lib.getLib pipewire)
          (lib.getLib fontconfig)
        ];

        dontConfigure = true;
        dontBuild = true;
        dontStrip = true;
        dontWrapGApps = true;

        unpackPhase = ''
          runHook preUnpack
          dpkg-deb -x "$src" .
          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/libexec" "$out/bin" "$out/share/skills"
          # 保留完整 Electron、渲染模块、PDFium WASM 和 XLSX sidecar，仅暴露 CLI。
          cp -a opt/GenOffice "$out/libexec/genoffice"
          ln -s ${jsdomModules}/node_modules "$out/libexec/genoffice/resources/cli/node_modules"
          cp -a "$out/libexec/genoffice/resources/cli/skills/genoffice" "$out/share/skills/genoffice"
          runHook postInstall
        '';

        preFixup = ''
          makeShellWrapper "$out/libexec/genoffice/genoffice" "$out/libexec/genoffice-app" \
            --prefix PATH : ${lib.makeBinPath [pkgs.xdg-utils]} \
            "''${gappsWrapperArgs[@]}" \
            --run 'if [ -z "''${DISPLAY:-}" ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then exec ${pkgs.xvfb-run}/bin/xvfb-run -a "''${0%/*}/genoffice/genoffice" "$@"; fi'
          makeWrapper "$out/libexec/genoffice/resources/cli/genoffice" "$out/bin/genoffice" \
            --prefix PATH : ${lib.makeBinPath [pkgs.coreutils]} \
            --set-default GENOFFICE_APP_BIN "$out/libexec/genoffice-app" \
            "''${gappsWrapperArgs[@]}"
        '';

        meta = {
          description = "GenOffice 官方 Release CLI 与 skill，保留完整本地文档引擎";
          homepage = "https://github.com/genspark-ai/genoffice";
          license = lib.licenses.asl20;
          mainProgram = "genoffice";
          platforms = ["x86_64-linux"];
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
  };
}
