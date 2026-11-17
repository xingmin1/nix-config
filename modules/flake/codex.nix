{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;

    system = stdenv.hostPlatform.system;

    # 上游资产名内嵌版本号，因此锁定同样无版本名的 SHA256SUMS.txt：
    # 文件名给出准确的 release 版本，行首给出资产哈希。
    checksumLines =
      lib.filter (line: line != "")
      (lib.splitString "\n" (builtins.readFile inputs.codex2apiChecksums));
    platformSuffix =
      {
        x86_64-linux = "linux_amd64";
        aarch64-linux = "linux_arm64";
      }
      .${
        system
      }
      or null;
    assetLine =
      lib.findFirst
      (line: lib.hasSuffix "_${platformSuffix}.tar.gz" line)
      (throw "codex2api 校验文件中未找到 ${platformSuffix} 资产")
      checksumLines;
    assetFields = lib.filter (field: field != "") (lib.splitString " " assetLine);
    assetName = builtins.elemAt assetFields 1;
    version = lib.removePrefix "codex2api_" (lib.removeSuffix "_${platformSuffix}.tar.gz" assetName);
    archive = pkgs.fetchurl {
      url = "https://github.com/xingmin1/codex2api/releases/download/v${version}/${assetName}";
      hash = builtins.convertHash {
        hash = builtins.elemAt assetFields 0;
        hashAlgo = "sha256";
        toHashFormat = "sri";
      };
    };
  in {
    packages =
      {
        codex = inputs.llm-agents.packages.${system}.codex;
      }
      // lib.optionalAttrs (platformSuffix != null) {
        codex2api = pkgs.stdenvNoCC.mkDerivation {
          pname = "codex2api";
          inherit version;

          src = archive;

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
