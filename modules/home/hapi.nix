{
  pkgs,
  lib,
  osConfig ? { },
  ...
}:
let
  hostName = lib.attrByPath [ "networking" "hostName" ] null osConfig;
  enableOnThisHost = hostName == "nixos";

  hapi = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "hapi";
    version = "0.9.2";

    src = pkgs.fetchurl {
      url = "https://github.com/tiann/hapi/releases/download/v${version}/hapi-linux-x64.tar.gz";
      hash = "sha256-nAI7bMyPjh+nF5gIgimgi+cMhem+Uv3sgMbid8MpCV8=";
    };
    sourceRoot = ".";

    nativeBuildInputs = [ pkgs.patchelf ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 hapi $out/bin/hapi
      runHook postInstall
    '';

    postFixup = ''
      patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" $out/bin/hapi
    '';

    meta = {
      description = "hapi：tiann/hapi 的命令行工具（预编译二进制）";
      homepage = "https://github.com/tiann/hapi";
      license = lib.licenses.agpl3Only;
      platforms = [ "x86_64-linux" ];
      mainProgram = "hapi";
    };
  };
in
{
  home.packages = lib.optionals enableOnThisHost [ hapi ];
}
