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

    collieRelease = builtins.fromJSON (builtins.readFile inputs.collieLatestRelease);
    collieVersion = lib.removePrefix "v" collieRelease.tag_name;
    collieTarget =
      {
        x86_64-linux = "linux-x64";
        aarch64-linux = "linux-arm64";
        aarch64-darwin = "macos-arm64";
      }
      .${
        system
      }
      or null;
    collieAssetName = "collie-${collieVersion}-${collieTarget}.tar.gz";
    collieAsset =
      lib.findFirst
      (asset: asset.name == collieAssetName)
      (throw "Collie release ${collieRelease.tag_name} 中未找到资产 ${collieAssetName}")
      collieRelease.assets;
    collieArchive = pkgs.fetchurl {
      url = collieAsset.browser_download_url;
      hash = hashFromGitHubAsset collieAsset;
    };
  in {
    packages = lib.optionalAttrs (collieTarget != null) {
      collie = pkgs.stdenv.mkDerivation {
        pname = "collie";
        version = collieVersion;

        src = collieArchive;

        nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [pkgs.autoPatchelfHook];

        dontConfigure = true;
        dontBuild = true;
        dontStrip = true;

        installPhase = ''
          runHook preInstall

          mkdir -p "$out/lib/collie" "$out/bin"
          cp -R ./. "$out/lib/collie/"
          chmod +x "$out/lib/collie/bin/collie"
          [ -d "$out/lib/collie/scripts" ] && chmod +x "$out/lib/collie/scripts"/*.sh
          ln -s "$out/lib/collie/bin/collie" "$out/bin/collie"

          runHook postInstall
        '';

        doInstallCheck = true;
        installCheckPhase = ''
          runHook preInstallCheck
          echo "collie --version says: $("$out/bin/collie" --version)"
          runHook postInstallCheck
        '';

        passthru.category = "AI Coding Agents";

        meta = {
          description = "Phone web UI for the AI agents running in your terminal, served over Tailscale";
          homepage = "https://github.com/AltanS/collie";
          license = lib.licenses.mit;
          mainProgram = "collie";
          platforms = [
            "x86_64-linux"
            "aarch64-linux"
            "aarch64-darwin"
          ];
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
  };
}
