# 说明：
#  - 迁移自 khanelinix 的 atuin 配置（精简并适配 Linux/NixOS 环境）。
#  - 提供统一的历史搜索（Ctrl-r）与守护进程，默认启用全部常见 shell 集成（bash/zsh/fish/nushell）。
#  - 若需禁用某 shell 的集成，请在上层模块覆盖对应的 enable*Integration 选项。
{ pkgs, ... }: {
  programs.atuin = {
    enable = true;

    # 启用各类 shell 的集成（提示符内 Ctrl-r 搜索历史等）
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;

    # 守护进程：用于更快的历史索引与查询
    daemon.enable = true;

    # 关键行为设置（与上游一致，避免误触与提升可用性）
    settings = {
      enter_accept = true;
      # 可用 workspace 模式，并可在界面中切换 filter_mode
      filter_mode = "workspace";
      keymap_mode = "auto";
      show_preview = true;
      style = "auto";
      update_check = false;
      workspaces = true;

      # 从历史中过滤不希望误触发的命令
      history_filter = [
        "^(sudo reboot)$"
        "^(reboot)$"
      ];
    };
  };
}
