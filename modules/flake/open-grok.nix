{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;

    system = stdenv.hostPlatform.system;
    release = builtins.fromJSON (builtins.readFile inputs.openGrokLatestRelease);
    version = lib.removePrefix "v" release.tag_name;
    target =
      {
        x86_64-linux = "linux-x86_64";
        aarch64-linux = "linux-aarch64";
      }
      .${
        system
      }
      or null;
    assetName = "open-grok-${target}";
    asset =
      lib.findFirst
      (candidate: candidate.name == assetName)
      (throw "Open Grok release ${release.tag_name} 中未找到资产 ${assetName}")
      release.assets;
    binary = pkgs.fetchurl {
      url = asset.browser_download_url;
      hash = builtins.convertHash {
        hash = lib.removePrefix "sha256:" asset.digest;
        hashAlgo = "sha256";
        toHashFormat = "sri";
      };
    };
  in {
    packages = lib.optionalAttrs (target != null) {
      open-grok = pkgs.stdenvNoCC.mkDerivation {
        pname = "open-grok";
        inherit version;

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
          platforms = [
            "x86_64-linux"
            "aarch64-linux"
          ];
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
  };
}
