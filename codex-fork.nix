# xingmin1/codex fork 的备用打包定义。
# 当前配置不导入此文件；需要切回 fork 时，将 `modules/flake/codex.nix` 中的
# `codex` 包来源改为 `import ../../codex-fork.nix {inherit inputs pkgs;}`。
{
  inputs,
  pkgs,
}: let
  inherit (pkgs) lib stdenv;

  system = stdenv.hostPlatform.system;
  codexTarget =
    {
      x86_64-linux = "x86_64-unknown-linux-musl";
    }
    .${
      system
    }
    or (throw "codex fork 暂不支持 ${system}");
  codexRelease = builtins.fromJSON (builtins.readFile inputs.codexLatestRelease);
  codexVersion = lib.removePrefix "v" codexRelease.tag_name;
  codexAssetName = "codex-package-${codexTarget}.tar.gz";
  codexAsset =
    lib.findFirst
    (asset: asset.name == codexAssetName)
    (throw "codex fork release ${codexRelease.tag_name} 中未找到资产 ${codexAssetName}")
    codexRelease.assets;
  codexArchive = pkgs.fetchurl {
    url = codexAsset.browser_download_url;
    hash = builtins.convertHash {
      hash = lib.removePrefix "sha256:" codexAsset.digest;
      hashAlgo = "sha256";
      toHashFormat = "sri";
    };
  };
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "codex";
    version = codexVersion;

    src = codexArchive;

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      tar -xzf "$src"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R bin codex-package.json codex-path codex-resources "$out"/
      runHook postInstall
    '';

    passthru.category = "AI Coding Agents";

    meta = {
      description = "OpenAI Codex CLI，来自 xingmin1/codex fork 的 GitHub release";
      homepage = "https://github.com/xingmin1/codex";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
