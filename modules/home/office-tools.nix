{
  flake,
  lib,
  pkgs,
  ...
}: let
  packages = flake.inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in {
  home.packages =
    lib.optional (packages ? genoffice) packages.genoffice
    ++ lib.optional (packages ? officecli) packages.officecli;

  home.file =
    lib.optionalAttrs (packages ? genoffice) {
      ".omp/agent/skills/genoffice".source = "${packages.genoffice}/share/skills/genoffice";
    }
    // lib.optionalAttrs (packages ? officecli) {
      ".omp/agent/skills/officecli".source = "${packages.officecli}/share/skills/officecli";
    };
}
