{flake, ...}: let
  inherit (flake) inputs;
  inherit (inputs) self;
in {
  imports = [
    self.homeModules.default
  ];

  # Defined by /modules/home/me.nix
  # And used all around in /modules/home/*
  me = {
    username = "xmin";
    fullname = "xmin";
    email = "zjwenx@qq.com";
  };

  services.sub2api = {
    enable = false;
    port = 8081;
    runMode = "simple";
  };
  services.cliProxyApi = {
    enable = false;
    port = 8399;
    networkName = "cpa-net";
    usageStatisticsEnabled = true;
    redisUsageQueueRetentionSeconds = 3600;
  };
  services.cpaUsageKeeper = {
    enable = false;
    port = 8400;
    networkName = "cpa-net";
    quotaAutoRefreshEnabled = true;
  };
  services.codex2api = {
    enable = true;
    port = 8080;
  };
  services.cloudflaredTunnel.enable = true;
  services.ccConnect.enable = true;

  home.stateVersion = "24.11";
}
