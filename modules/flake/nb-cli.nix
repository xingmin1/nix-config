{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;
    release = import ../../lib/github-release.nix {
      inherit lib;
      inherit (pkgs) fetchurl;
      metadata = inputs.nbCliRelease;
    };
    inherit (release) version;
    assets = {
      x86_64-linux = "nb-linux-amd64";
      aarch64-linux = "nb-linux-arm64";
    };
    asset = assets.${stdenv.hostPlatform.system} or null;
    binary = release.asset asset;
    skills = inputs.nbCliSkills;
  in {
    packages = lib.optionalAttrs (asset != null) {
      nb-cli = pkgs.stdenvNoCC.mkDerivation {
        pname = "nb-cli";
        inherit version;
        src = skills;

        # 官方 Linux 资产为静态 musl：无 ELF interpreter/NEEDED，无需 autoPatchelf。
        # OpenSSL 已 vendored；ZeroMQ 使用 Rust 实现，不依赖系统 libzmq。
        dontConfigure = true;
        dontBuild = true;
        dontStrip = true;
        dontPatchShebangs = true;

        installPhase = ''
          runHook preInstall
          install -Dm755 ${binary} "$out/bin/nb"
          install -d "$out/share/skills"
          cp -R skills/notebook-cli "$out/share/skills/notebook-cli"
          install -Dm644 LICENSE "$out/share/licenses/nb-cli/LICENSE"
          runHook postInstall
        '';

        meta = {
          description = "Jupyter nb-cli 官方 Release 命令行工具及完整 Notebook 技能";
          homepage = "https://github.com/jupyter-ai-contrib/nb-cli";
          changelog = "https://github.com/jupyter-ai-contrib/nb-cli/releases/latest";
          license = lib.licenses.bsd3;
          mainProgram = "nb";
          platforms = builtins.attrNames assets;
          sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
        };
      };
    };
  };
}
