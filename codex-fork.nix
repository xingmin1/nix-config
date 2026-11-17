# xingmin1/codex fork 的备用打包定义。
# 当前配置不导入此文件；需要切回 fork 时，将 `modules/flake/codex.nix` 中的
# `codex` 包来源改为 `import ../../codex-fork.nix {inherit inputs pkgs;}`。
{
  inputs,
  pkgs,
}: let
  inherit (pkgs) lib;
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "codex";
    version = "latest";

    # 上游资产名不含版本号，可直接锁定 latest/download 的稳定指针。
    src = inputs.codexForkLinuxX64;

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
