{
  config,
  flake,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ccConnect;

  inherit (lib) mkEnableOption mkIf mkOption types;

  ccConnectPackage = flake.inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.cc-connect;
in {
  options.services.ccConnect = {
    enable = mkEnableOption "cc-connect 用户级服务";

    package = mkOption {
      type = types.package;
      default = ccConnectPackage;
      description = "用于运行 cc-connect 的包，默认使用本仓库 flake 输出。";
    };

    configFile = mkOption {
      type = types.path;
      default = "${config.home.homeDirectory}/.cc-connect/config.toml";
      description = "cc-connect 配置文件路径。";
    };

    workingDirectory = mkOption {
      type = types.path;
      default = "${config.home.homeDirectory}/.cc-connect";
      description = "cc-connect 运行目录。";
    };

    logFile = mkOption {
      type = types.path;
      default = "${config.home.homeDirectory}/.cc-connect/logs/cc-connect.log";
      description = "cc-connect 日志文件路径。";
    };

    logMaxSize = mkOption {
      type = types.ints.positive;
      default = 10485760;
      description = "cc-connect 单个日志文件最大字节数。";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "services.ccConnect 依赖 systemd user services，只能在 Linux 上启用。";
      }
    ];

    home.packages = [cfg.package];

    systemd.user.startServices = "sd-switch";

    systemd.user.services.cc-connect = {
      Unit = {
        Description = "cc-connect - AI Agent Chat Bridge";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/cc-connect --config ${cfg.configFile}";
        WorkingDirectory = cfg.workingDirectory;
        Restart = "on-failure";
        RestartSec = 10;
        Environment = [
          "CC_LOG_FILE=${cfg.logFile}"
          "CC_LOG_MAX_SIZE=${toString cfg.logMaxSize}"
          "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin"
        ];
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
