{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages.tftp-now = pkgs.stdenvNoCC.mkDerivation {
      pname = "tftp-now";
      version = "latest";

      src = inputs.tftpNowBinary;
      dontUnpack = true;

      installPhase = ''
        runHook preInstall
        install -Dm755 "$src" "$out/bin/tftp-now"
        runHook postInstall
      '';

      meta = {
        description = "可立即使用的单二进制 TFTP 服务端与客户端";
        homepage = "https://github.com/puhitaku/tftp-now";
        license = pkgs.lib.licenses.mit;
        mainProgram = "tftp-now";
        platforms = ["x86_64-linux"];
        sourceProvenance = [pkgs.lib.sourceTypes.binaryNativeCode];
      };
    };
  };
}
