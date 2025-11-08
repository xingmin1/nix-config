{ ... }: {
  # 通用 shell 配置：跨 Bash/Zsh/Fish 的公共程序与提示主题
  programs = {
    # 目录跳转工具
    zoxide.enable = true;

    # 统一的 prompt 主题
    starship = {
      enable = true;
      settings = {
        username = {
          style_user = "blue bold";
          style_root = "red bold";
          format = "[$user]($style) ";
          disabled = false;
          show_always = true;
        };
        hostname = {
          ssh_only = false;
          ssh_symbol = "🌐 ";
          format = "on [$hostname](bold red) ";
          trim_at = ".local";
          disabled = false;
        };
      };
    };
  };
}

