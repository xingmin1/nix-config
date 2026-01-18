{
  config,
  pkgs,
  ...
}:
{
  hapi = pkgs.stdenv.mkDerivation {
    pname = "hapi";

    src = pkgs.fetchurl {
      url = "https://github.com/tiann/hapi/releases/download/v0.9.2/hapi-linux-x64.tar.gz";
      hash = "sha256:9c023b6ccc8f8e1fa71798088229a08be70c85e9be52fdec80c6e277c329095f";
    };

    dontUnpack = true;

    installPhase = ''
      install -Dm755 $src $out/bin/hapi
    '';
  };
}
