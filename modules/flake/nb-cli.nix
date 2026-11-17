{...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;
    version = "0.0.10";
    assets = {
      x86_64-linux = {
        name = "nb-linux-amd64";
        hash = "sha256-CRDa8wMtpaPlKVEHLT3bDrKg2xOt+brLnhuK90WT/Z4=";
      };
      aarch64-linux = {
        name = "nb-linux-arm64";
        hash = "sha256-KggTa6i3NSVv/jJoiLuUJsAlLDekMwzdo6MowzZoODQ=";
      };
    };
    asset = assets.${stdenv.hostPlatform.system} or null;
    binary = pkgs.fetchurl {
      url = "https://github.com/jupyter-ai-contrib/nb-cli/releases/download/v${version}/${asset.name}";
      inherit (asset) hash;
    };
    # 同标签归档仅提供完整官方技能和许可证，不参与源码编译。
    skills = pkgs.fetchurl {
      url = "https://codeload.github.com/jupyter-ai-contrib/nb-cli/tar.gz/refs/tags/v${version}";
      name = "nb-cli-${version}-skills.tar.gz";
      hash = "sha256-kSDYKKvVRu9CJDpNFu/NeLk3Q0DWl0dqT91IeA/EFgg=";
    };
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
          changelog = "https://github.com/jupyter-ai-contrib/nb-cli/releases/tag/v${version}";
          license = lib.licenses.bsd3;
          mainProgram = "nb";
          platforms = builtins.attrNames assets;
          sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
        };
      };
    };
  };
}
