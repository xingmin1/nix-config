{...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;

    system = stdenv.hostPlatform.system;
    jcodeTarget =
      {
        x86_64-linux = "linux-x86_64";
      }
      .${
        system
      }
      or null;
  in {
    packages = lib.optionalAttrs (jcodeTarget != null) {
      jcode = pkgs.stdenvNoCC.mkDerivation rec {
        pname = "jcode";
        version = "0.56.0";

        src = pkgs.fetchurl {
          url = "https://github.com/1jehuang/jcode/releases/download/v${version}/jcode-${jcodeTarget}.tar.gz";
          hash = "sha256-2RGQZnFivnl6IvEmxZ/e8z17CRY4Qk927r9kC7cmHGs=";
        };

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
          install -Dm755 jcode-${jcodeTarget} "$out/libexec/jcode/jcode-${jcodeTarget}"
          install -Dm755 jcode-${jcodeTarget}.bin "$out/libexec/jcode/jcode-${jcodeTarget}.bin"
          makeWrapper "$out/libexec/jcode/jcode-${jcodeTarget}" "$out/bin/jcode" \
            --set JCODE_NO_TELEMETRY 1
          runHook postInstall
        '';

        passthru.category = "AI Coding Agents";

        meta = {
          description = "JCode AI 编程助手的官方预编译版本";
          homepage = "https://github.com/1jehuang/jcode";
          license = lib.licenses.mit;
          mainProgram = "jcode";
          platforms = ["x86_64-linux"];
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
  };
}
