{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;

    system = stdenv.hostPlatform.system;
    archives = {
      x86_64-linux = inputs.jcodeLinuxX64;
      aarch64-linux = inputs.jcodeLinuxAarch64;
    };
    targetNames = {
      x86_64-linux = "linux-x86_64";
      aarch64-linux = "linux-aarch64";
    };
    archive = archives.${system} or null;
    target = targetNames.${system} or null;
  in {
    packages = lib.optionalAttrs (archive != null) {
      jcode = pkgs.stdenvNoCC.mkDerivation {
        pname = "jcode";
        version = "latest";

        src = archive;

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.makeWrapper
        ];
        buildInputs = [
          pkgs.glibc
          pkgs.stdenv.cc.cc.lib
        ];

        dontConfigure = true;
        dontBuild = true;

        unpackPhase = ''
          runHook preUnpack
          tar -xzf "$src"
          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 jcode-${target} "$out/libexec/jcode/jcode-${target}"
          install -Dm755 jcode-${target}.bin "$out/libexec/jcode/jcode-${target}.bin"
          makeWrapper "$out/libexec/jcode/jcode-${target}" "$out/bin/jcode" \
            --set JCODE_NO_TELEMETRY 1
          runHook postInstall
        '';

        passthru.category = "AI Coding Agents";

        meta = {
          description = "JCode AI 编程助手的官方预编译版本";
          homepage = "https://github.com/1jehuang/jcode";
          license = lib.licenses.mit;
          mainProgram = "jcode";
          platforms = builtins.attrNames archives;
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
  };
}
