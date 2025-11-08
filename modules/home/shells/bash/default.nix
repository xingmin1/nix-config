{
  # 迁移自 khanelinix：Bash 基础启用与补全。
  #
  # 适配说明：
  # - 移除 fastfetch 相关引用，保留最小可用初始化。
  pkgs,
  ...
}: {
  programs.bash = {
    enable = true;
    # 使用带 readline/可编程补全的交互版 bash，避免 "shopt: progcomp"、"set: vi" 等报错
    package = pkgs.bashInteractive;
    enableCompletion = true;
    # 启用 Vim 按键模式
    initExtra = ''
      set -o vi
    '';
  };
}
