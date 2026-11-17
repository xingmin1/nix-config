{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib stdenv;

    # 上游在每个 Release 里同时发布无版本名的 latest 别名资产，可直接锁定为稳定指针。
    archives = {
      x86_64-linux = inputs.slackCliLinuxAmd64;
      aarch64-linux = inputs.slackCliLinuxArm64;
      x86_64-darwin = inputs.slackCliMacosAmd64;
      aarch64-darwin = inputs.slackCliMacosArm64;
    };
    archive = archives.${stdenv.hostPlatform.system} or null;

    # macOS 压缩包不含许可证，复用同一 Release 的 Linux 发行物，不下载源码。
    installLicense =
      if stdenv.hostPlatform.isDarwin
      then ''
        tar -xOf ${inputs.slackCliLinuxAmd64} LICENSE > "$out/share/licenses/slack-cli-official/LICENSE"
      ''
      else ''
        install -Dm644 LICENSE "$out/share/licenses/slack-cli-official/LICENSE"
      '';
  in {
    packages = lib.optionalAttrs (archive != null) {
      slack-cli-official = pkgs.stdenvNoCC.mkDerivation {
        pname = "slack-cli-official";
        version = "latest";
        src = archive;

        dontConfigure = true;
        dontBuild = true;
        dontStrip = true;
        dontPatchELF = true;

        unpackPhase = ''
          runHook preUnpack
          tar -xzf "$src"
          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 bin/slack "$out/bin/slack"
          mkdir -p "$out/share/licenses/slack-cli-official"
          ${installLicense}
          runHook postInstall
        '';

        doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
        installCheckPhase = ''
          runHook preInstallCheck
          export HOME="$TMPDIR/slack-cli-home"
          export XDG_CONFIG_HOME="$HOME/.config"
          mkdir -p "$HOME"
          "$out/bin/slack" --version --skip-update | grep -E "^Using slack v[0-9]"
          "$out/bin/slack" --help --skip-update > /dev/null
          "$out/bin/slack" login --help --skip-update > /dev/null
          runHook postInstallCheck
        '';

        meta = {
          description = "Slack 官方应用开发命令行工具，使用最新 Release 预编译发行物";
          homepage = "https://github.com/slackapi/slack-cli";
          license = lib.licenses.asl20;
          mainProgram = "slack";
          platforms = builtins.attrNames archives;
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    };
  };
}
