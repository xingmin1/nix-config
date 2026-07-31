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
  # ast-bro 与 sb 由 resource-control 模块提供受 cgroup 隔离的入口。
  # 这里保留原始包路径供安装器读取 skill，不直接放入用户 PATH。
  home.file.".codex/skills/ast-bro/SKILL.md".source = astBroSkill;

  home.activation.astBroAgentSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    export HOME=${lib.escapeShellArg config.home.homeDirectory}

    ${installForAgent "codex"}
    ${installForAgent "claude-code"}
  '';
}
