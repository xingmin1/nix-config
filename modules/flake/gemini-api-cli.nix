{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;
    archives = {
      x86_64-linux = inputs.geminiApiLinuxX64;
      aarch64-linux = inputs.geminiApiLinuxArm64;
    };
    archive = archives.${stdenv.hostPlatform.system} or null;
  in {
    packages = lib.optionalAttrs (archive != null) {
      gemini-api-cli = pkgs.stdenvNoCC.mkDerivation {
        pname = "gemini-api-cli";
        version = "0.5.0";
        src = archive;
        dontConfigure = true;
        dontBuild = true;
        dontStrip = true;

        unpackPhase = ''
          runHook preUnpack
          tar -xzf "$src"
          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 gemini-api "$out/bin/gemini-api"
          install -Dm644 LICENSE "$out/share/licenses/gemini-api-cli/LICENSE"
          install -Dm644 README.md "$out/share/doc/gemini-api-cli/README.md"
          runHook postInstall
        '';

        meta = {
          description = "Official Google Gemini Interactions API command-line client";
          homepage = "https://github.com/google-gemini/gemini-api-cli";
          changelog = "https://github.com/google-gemini/gemini-api-cli/releases/tag/v0.5.0";
          license = lib.licenses.asl20;
          mainProgram = "gemini-api";
          platforms = builtins.attrNames archives;
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
  };
}
