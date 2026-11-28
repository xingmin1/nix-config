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

    # The requested singular .agents/skill directory is kept verbatim.
    home.file.".agents/skill/gemini-api-cli".source = "${flake.inputs.geminiApiCliSkill}/skills/gemini-api-cli";
  }
