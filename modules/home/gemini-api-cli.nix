{
  config,
  flake,
  lib,
  pkgs,
  ...
}: let
  packages = flake.inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in
  lib.mkIf (packages ? gemini-api-cli) {
    home.packages = [packages.gemini-api-cli];

    home.file.".agents/skills/gemini-api-cli".source = "${flake.inputs.geminiApiCliSkill}/skills/gemini-api-cli";
  }
