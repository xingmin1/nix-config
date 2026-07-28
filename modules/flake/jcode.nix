{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;

    system = stdenv.hostPlatform.system;
    hashFromGitHubAsset = asset:
      builtins.convertHash {
        hash = lib.removePrefix "sha256:" asset.digest;
        hashAlgo = "sha256";
        toHashFormat = "sri";
      };

    jcodeRelease = builtins.fromJSON (builtins.readFile inputs.jcodeLatestRelease);
    jcodeVersion = lib.removePrefix "v" jcodeRelease.tag_name;
    jcodeTarget =
      {
        x86_64-linux = "linux-x86_64";
        aarch64-linux = "linux-aarch64";
      }
      .${
        system
      }
      or null;
    jcodeAssetName = "jcode-${jcodeTarget}.tar.gz";
    jcodeAsset =
      lib.findFirst
      (asset: asset.name == jcodeAssetName)
      (throw "Jcode release ${jcodeRelease.tag_name} 中未找到资产 ${jcodeAssetName}")
      jcodeRelease.assets;
    jcodeArchive = pkgs.fetchurl {
      url = jcodeAsset.browser_download_url;
      hash = hashFromGitHubAsset jcodeAsset;
    };
  in {
    packages = lib.optionalAttrs (jcodeTarget != null) {
      jcode = pkgs.stdenvNoCC.mkDerivation rec {
        pname = "jcode";
        version = jcodeVersion;

        src = jcodeArchive;

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
