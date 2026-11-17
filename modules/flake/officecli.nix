{...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;
    version = "1.0.157";
    assets = {
      x86_64-linux = {
        name = "officecli-linux-x64";
        hash = "sha256-+O7+iNv6dGS+5CHlQh7+V/wmvDGAsw5W7vWFlMgkXJQ=";
      };
      aarch64-linux = {
        name = "officecli-linux-arm64";
        hash = "sha256-YNuSbIoTcZhLnpliKoNHd777Arb3PQ8//5FP/MJ2DS8=";
      };
    };
    asset = assets.${stdenv.hostPlatform.system} or null;
    binary = pkgs.fetchurl {
      url = "https://github.com/iOfficeAI/OfficeCLI/releases/download/v${version}/${asset.name}";
      inherit (asset) hash;
    };
    # 标签归档仅提供完整官方技能和许可证，不参与编译。
    skills = pkgs.fetchurl {
      url = "https://codeload.github.com/iOfficeAI/OfficeCLI/tar.gz/refs/tags/v${version}";
      name = "officecli-${version}-skills.tar.gz";
      hash = "sha256-z9hYyjLMPstRsWuIKrJhRReSHEsUFnS4KwiD7rB6N1Q=";
    };
    # 自包含 .NET 二进制仍通过 dlopen 加载系统库，不能只修复 ELF 的 NEEDED 项。
    runtimeLibraries = with pkgs; [stdenv.cc.cc.lib icu openssl zlib krb5];
  in {
    packages = lib.optionalAttrs (asset != null) {
      officecli = pkgs.stdenvNoCC.mkDerivation {
        pname = "officecli";
        inherit version;
        src = skills;

        nativeBuildInputs = with pkgs; [autoPatchelfHook makeWrapper];
        buildInputs = runtimeLibraries;
        dontConfigure = true;
        dontBuild = true;
        dontStrip = true;
        # 技能内的参考脚本保持上游原文，不改写 shebang。
        dontPatchShebangs = true;

        installPhase = ''
          runHook preInstall
          install -Dm755 ${binary} "$out/libexec/officecli/officecli"
          install -Dm644 SKILL.md "$out/share/skills/officecli/SKILL.md"
          # 保留 skills/<子技能>/reference 的层级及跨子技能相对引用。
          cp -R skills "$out/share/skills/officecli/skills"
          install -Dm644 LICENSE "$out/share/licenses/officecli/LICENSE"
          install -Dm644 NOTICE "$out/share/licenses/officecli/NOTICE"
          install -Dm644 THIRD-PARTY-NOTICES.txt "$out/share/licenses/officecli/THIRD-PARTY-NOTICES.txt"
          runHook postInstall
        '';

        postFixup = ''
          # .NET 按真实文件名生成根命令名，不能使用 wrapProgram 的隐藏文件名。
          makeWrapper "$out/libexec/officecli/officecli" "$out/bin/officecli" \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibraries} \
            --set OFFICECLI_SKIP_UPDATE 1
        '';

        meta = {
          description = "OfficeCLI 官方 Release 命令行工具及完整文档编辑技能";
          homepage = "https://github.com/iOfficeAI/OfficeCLI";
          changelog = "https://github.com/iOfficeAI/OfficeCLI/releases/tag/v${version}";
          license = lib.licenses.asl20;
          mainProgram = "officecli";
          platforms = builtins.attrNames assets;
          sourceProvenance = with lib.sourceTypes; [binaryNativeCode binaryBytecode];
        };
      };
    };
  };
}
