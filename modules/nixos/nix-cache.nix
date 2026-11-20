{
  # 镜像沿用官方签名。数字更小的缓存优先，未命中时仍可使用官方和第三方缓存。
  nix.settings.substituters = [
    "https://mirror.sjtu.edu.cn/nix-channels/store?priority=15"
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=20"
    "https://mirrors.ustc.edu.cn/nix-channels/store?priority=25"
  ];
}
