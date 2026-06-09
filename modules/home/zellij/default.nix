{
  lib,
  pkgs,
  ...
}: let
  zellijPackage = pkgs.zellij;
  zellijCompletions = pkgs.runCommand "zellij-completions-${zellijPackage.version}" {} ''
    mkdir -p \
      "$out/share/bash-completion/completions" \
      "$out/share/fish/vendor_completions.d" \
      "$out/share/zsh/site-functions"

    ${lib.getExe zellijPackage} setup --generate-completion bash > "$out/share/bash-completion/completions/zellij"
    ${lib.getExe zellijPackage} setup --generate-completion fish > "$out/share/fish/vendor_completions.d/zellij.fish"
    ${lib.getExe zellijPackage} setup --generate-completion zsh > "$out/share/zsh/site-functions/_zellij"
  '';
  shellAliases = {
    "zj" = "zellij";
  };
in {
  programs.zellij = {
    enable = true;
    package = zellijPackage;
    enableBashIntegration = false;
    enableZshIntegration = false;
    enableFishIntegration = false;
    extraConfig = builtins.readFile ./config.kdl;
  };
  catppuccin.zellij.enable = true;

  xdg.configFile."fish/completions/zellij.fish".source = "${zellijCompletions}/share/fish/vendor_completions.d/zellij.fish";

  programs.bash.initExtra = ''
    if [[ -r "${zellijCompletions}/share/bash-completion/completions/zellij" ]]; then
      source "${zellijCompletions}/share/bash-completion/completions/zellij"
      complete -o default -F _zellij zellij zj 2>/dev/null || true
    fi
  '';

  programs.fish.interactiveShellInit = ''
    complete -c zj -w zellij
  '';

  programs.zsh.completionInit = lib.mkAfter ''
    source "${zellijCompletions}/share/zsh/site-functions/_zellij"
    compdef _zellij zellij zj
  '';

  # home.shellAliases 在 nushell 不生效，因此这里额外同步一份别名。
  home.shellAliases = shellAliases;
  programs.nushell.shellAliases = shellAliases;
}
