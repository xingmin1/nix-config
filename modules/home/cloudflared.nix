{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.cloudflaredTunnel;

  inherit (lib) mkEnableOption mkIf mkOption types;

  serviceArgs =
    [
      (lib.getExe cfg.package)
      "tunnel"
      "--no-autoupdate"
      "--loglevel"
      cfg.logLevel
    ]
    ++ lib.optionals (cfg.metrics != null) [
      "--metrics"
      cfg.metrics
    ]
    ++ [
      "run"
      "--token-file"
      cfg.tokenFile
    ];
in {
  options.services.cloudflaredTunnel = {
    enable = mkEnableOption "Cloudflare Tunnel 用户级连接器";

    package = mkOption {
      type = types.package;
      default = pkgs.cloudflared;
      description = "用于运行 Cloudflare Tunnel 连接器的 cloudflared 包。";
    };

    tokenFile = mkOption {
      type = types.str;
      default = "${config.xdg.configHome}/cloudflared/tunnel-token";
      description = "Cloudflare Tunnel token 文件路径。该文件应由本机私有配置提供，不应提交进仓库。";
    };

    logLevel = mkOption {
      type = types.enum [
        "debug"
        "info"
        "warn"
        "error"
        "fatal"
      ];
      default = "info";
      description = "cloudflared 运行日志级别。";
    };

    metrics = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "cloudflared 指标监听地址；设为 null 时使用 cloudflared 默认值。";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "services.cloudflaredTunnel 依赖 systemd user services，只能在 Linux 上启用。";
      }
    ];

    xdg.enable = true;
    home.packages = [cfg.package];
    systemd.user.startServices = "sd-switch";

    home.activation.ensureCloudflaredTunnelDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg (builtins.dirOf cfg.tokenFile)}
    '';

    systemd.user.services.cloudflared-tunnel = {
      Unit = {
        Description = "Cloudflare Tunnel 用户级连接器";
        Wants = ["network-online.target"];
        After = ["network-online.target"];
      };

      Service = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/test -s ${lib.escapeShellArg cfg.tokenFile}";
        ExecStart = lib.escapeShellArgs serviceArgs;
        Restart = "always";
        RestartSec = 5;
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
