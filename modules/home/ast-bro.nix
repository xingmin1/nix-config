{
  config,
  flake,
  lib,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  astBroPackage = flake.inputs.ast-bro.packages.${system}.default;
  astBroBinary = "${astBroPackage}/bin/ast-bro";
  astBroSkill = flake.inputs.ast-bro + "/skills/ast-bro/SKILL.md";
  installForAgent = target: ''
    ${astBroBinary} install --target ${target} --global --force
    ${astBroBinary} install --target ${target} --global --skills --force
  '';
in {
  home.packages = [
    astBroPackage
  ];

  # Codex 当前仍兼容 $CODEX_HOME/skills；上游 installer 只写 ~/.agents/skills。
  home.file.".codex/skills/ast-bro/SKILL.md".source = astBroSkill;

  home.activation.astBroAgentSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    export HOME=${lib.escapeShellArg config.home.homeDirectory}

    ${installForAgent "codex"}
    ${installForAgent "claude-code"}
  '';
}
