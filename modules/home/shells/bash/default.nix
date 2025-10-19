{
  # 迁移自 khanelinix：Bash 基础启用与补全。
  #
  # 适配说明：
  # - 移除 fastfetch 相关引用，保留最小可用初始化。
  config,
  lib,
  ...
}:
{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    initExtra = "";
  };
}

