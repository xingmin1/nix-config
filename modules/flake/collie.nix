{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;

    # 上游发布流程维护 packaging/nix/sources.json：版本号加各平台资产的 url/sha256。
    release = builtins.fromJSON (builtins.readFile "${inputs.collieRepo}/packaging/nix/sources.json");
    platformNames = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    platformName = platformNames.${stdenv.hostPlatform.system} or null;
    asset =
      if platformName == null
      then null
      else release.platforms.${platformName} or null;
  in {
    packages = lib.optionalAttrs (asset != null) {
      collie = pkgs.stdenv.mkDerivation {
        pname = "collie";
        version = release.version;

        src = pkgs.fetchurl {
          inherit (asset) url sha256;
        };

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
          platforms = builtins.attrNames platformNames;
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
  };
}
