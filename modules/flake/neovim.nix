# 提供一个简化的 Neovim 包输出：直接导出上游 pkgs.neovim
{...}: {
  perSystem = { pkgs, ... }: {
    packages.neovim = pkgs.neovim;
  };
}
