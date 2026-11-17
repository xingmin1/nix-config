{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;

    binaries = {
      x86_64-linux = inputs.openGrokLinuxX64;
      aarch64-linux = inputs.openGrokLinuxAarch64;
    };
    binary = binaries.${stdenv.hostPlatform.system} or null;
    ompBinaries = {
      x86_64-linux = inputs.ompLinuxX64;
      aarch64-linux = inputs.ompLinuxAarch64;
    };
    ompBinary = ompBinaries.${stdenv.hostPlatform.system} or null;
  in {
    packages =
      lib.optionalAttrs (binary != null) {
        open-grok = pkgs.stdenvNoCC.mkDerivation {
          pname = "open-grok";
          version = "latest";

          src = binary;
          dontUnpack = true;

          nativeBuildInputs = [
            pkgs.autoPatchelfHook
            pkgs.makeWrapper
          ];
          buildInputs = [
            pkgs.glibc
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ];

          installPhase = ''
            runHook preInstall
            install -Dm755 "$src" "$out/libexec/open-grok/open-grok"
            makeWrapper "$out/libexec/open-grok/open-grok" "$out/bin/open-grok" \
              --set OPENGROK_DISABLE_AUTOUPDATER 1
            runHook postInstall
          '';

          passthru.category = "AI Coding Agents";

          meta = {
            description = "Open Grok AI 编程助手的官方预编译版本";
            homepage = "https://github.com/mweinbach/open-grok";
            license = lib.licenses.asl20;
            mainProgram = "open-grok";
            platforms = builtins.attrNames binaries;
            sourceProvenance = [lib.sourceTypes.binaryNativeCode];
          };
        };
      }
      // lib.optionalAttrs (ompBinary != null) {
        omp-release = pkgs.stdenvNoCC.mkDerivation {
          pname = "omp";
          version = "latest";
          src = ompBinary;
          dontUnpack = true;
          dontStrip = true;
          nativeBuildInputs = [pkgs.makeWrapper pkgs.patchelf];
          installPhase = ''
            runHook preInstall
            install -Dm755 "$src" "$out/libexec/omp"
            # 仅改 ELF 解释器：修改 RPATH 会破坏 Bun 内嵌二进制的版本段。
            patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" "$out/libexec/omp"
            makeWrapper "$out/libexec/omp" "$out/bin/omp" \
              --set-default OMP_NATIVE_LIBRARY_PATH "${lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib]}"
            runHook postInstall
          '';
          meta = {
            description = "OMP 官方 GitHub Release 预编译版本";
            homepage = "https://github.com/can1357/oh-my-pi";
            license = lib.licenses.mit;
            mainProgram = "omp";
            platforms = builtins.attrNames ompBinaries;
            sourceProvenance = [lib.sourceTypes.binaryNativeCode];
          };
        };
      };
  };
}
