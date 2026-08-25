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

    codex2apiRelease = builtins.fromJSON (builtins.readFile inputs.codex2apiLatestRelease);
    codex2apiVersion = lib.removePrefix "v" codex2apiRelease.tag_name;
    codex2apiPlatformSuffix =
      {
        x86_64-linux = "linux_amd64";
        aarch64-linux = "linux_arm64";
      }
      .${
        system
      }
      or null;
    codex2apiAssetName = "codex2api_${codex2apiVersion}_${codex2apiPlatformSuffix}.tar.gz";
    codex2apiAsset =
      lib.findFirst
      (asset: asset.name == codex2apiAssetName)
      (throw "codex2api release ${codex2apiRelease.tag_name} 中未找到资产 ${codex2apiAssetName}")
      codex2apiRelease.assets;
    codex2apiArchive = pkgs.fetchurl {
      url = codex2apiAsset.browser_download_url;
      hash = hashFromGitHubAsset codex2apiAsset;
    };
  in {
    packages =
      {
        codex = inputs.llm-agents.packages.${system}.codex;
      }
      // lib.optionalAttrs (codex2apiPlatformSuffix != null) {
        codex2api = pkgs.stdenvNoCC.mkDerivation {
          pname = "codex2api";
          version = codex2apiVersion;

          src = codex2apiArchive;

          dontConfigure = true;
          dontBuild = true;

          unpackPhase = ''
            runHook preUnpack
            tar -xzf "$src"
            runHook postUnpack
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 codex2api "$out/bin/codex2api"
            install -Dm644 README.md "$out/share/doc/codex2api/README.md"
            install -Dm644 .env.example "$out/share/doc/codex2api/env.example"
            runHook postInstall
          '';

          meta = {
            description = "Codex2API release 构建，来自 xingmin1/codex2api 最新 GitHub release";
            homepage = "https://github.com/xingmin1/codex2api";
            license = lib.licenses.mit;
            mainProgram = "codex2api";
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
