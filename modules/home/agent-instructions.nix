{config, ...}: let
  sharedAgentsFile = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.codex/AGENTS.md";
in {
  home.file = {
    ".grok/AGENTS.md".source = sharedAgentsFile;
    "AGENTS.md".source = sharedAgentsFile;
  };
}
