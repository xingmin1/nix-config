{
  config,
  pkgs,
  ...
}: {
  home.packages = [pkgs.git-credential-manager];

  home.shellAliases = {
    g = "git";
    lg = "lazygit";
  };

  # https://nixos.asia/en/git
  programs = {
    git = {
      enable = true;
      settings = {
        user.name = config.me.fullname;
        user.email = config.me.email;
        core.editor = "hx";
        credential = {
          helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
          credentialStore = "gpg";
          gitLabAuthModes = "pat";
          guiPrompt = false;
        };

        alias.ci = "commit";

        # 示例：如需自定义默认分支或拉取策略，可取消注释
        # init.defaultBranch = "master";
        # pull.rebase = false;
      };
    };
    lazygit.enable = true;
  };
}
