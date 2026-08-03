{
  # 构建负载最多使用当前可见内存的 80%，为登录会话和 AI 服务保留余量。
  systemd.slices.build = {
    description = "Disposable build workloads";
    sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureDurationSec = "15s";
      ManagedOOMMemoryPressureLimit = "70%";
      ManagedOOMSwap = "kill";
      MemoryMax = "80%";
      MemorySwapMax = "8G";
    };
  };

  systemd.oomd = {
    enable = true;
    enableRootSlice = false;
    enableSystemSlice = false;
    # build.slice 会单独注册为监控点，避免通配规则把受保护的 ai.slice 也变成监控点。
    enableUserSlices = false;
    settings.OOM = {
      DefaultMemoryPressureDurationSec = "20s";
      DefaultMemoryPressureLimit = "80%";
      SwapUsedLimit = "90%";
    };
  };

  services.earlyoom.enable = false;

  systemd.services.nix-daemon.serviceConfig = {
    OOMPolicy = "kill";
    OOMScoreAdjust = 500;
    Restart = "on-failure";
    RestartSec = "5s";
    Slice = "build.slice";
  };

  # 用户管理器必须比普通工作负载更晚成为内核 OOM 的牺牲品，否则所有用户服务会一起退出。
  systemd.services."user@".serviceConfig.OOMScoreAdjust = -250;

  nix.settings = {
    cores = 6;
    max-jobs = 3;
    use-cgroups = true;

    # 大型源码构建前优先回收不可达 store 路径，避免根分区被临时产物耗尽。
    min-free = 32 * 1024 * 1024 * 1024;
    max-free = 64 * 1024 * 1024 * 1024;
  };
}
