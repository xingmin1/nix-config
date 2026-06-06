{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.codex2api;

  inherit (lib) mkEnableOption mkIf mkOption types;

  podman = lib.getExe pkgs.podman;

  name = "codex2api";
  configDir = "${config.xdg.configHome}/${name}";
  dataDir = "${config.xdg.dataHome}/${name}";
  stateDir = "${config.xdg.stateHome}/${name}";
  envFile = "${configDir}/env";
  credentialsFile = "${configDir}/credentials.env";
  containerPort = 8080;

  mkPortMapping = host: hostPort: containerPort: "${host}:${toString hostPort}:${toString containerPort}";

  init = pkgs.writeShellApplication {
    name = "codex2api-init";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.openssl
      pkgs.podman
    ];
    text = ''
            set -euo pipefail

            install -d -m 700 \
              ${lib.escapeShellArg configDir} \
              ${lib.escapeShellArg dataDir} \
              ${lib.escapeShellArg "${stateDir}/logs"}

            if [ ! -f ${lib.escapeShellArg credentialsFile} ]; then
              umask 077
              cat > ${lib.escapeShellArg credentialsFile} <<EOF
      ADMIN_SECRET=$(openssl rand -hex 24)
      CODEX_API_KEY=sk-codex2api-$(openssl rand -hex 24)
      EOF
            fi

            # shellcheck source=/dev/null
            . ${lib.escapeShellArg credentialsFile}

            if [ -z "''${ADMIN_SECRET:-}" ]; then
              echo "ADMIN_SECRET is empty in ${lib.escapeShellArg credentialsFile}" >&2
              exit 1
            fi

            if [ -z "''${CODEX_API_KEY:-}" ]; then
              echo "CODEX_API_KEY is empty in ${lib.escapeShellArg credentialsFile}" >&2
              exit 1
            fi

            umask 077
            cat > ${lib.escapeShellArg envFile} <<EOF
      CODEX_PORT=${toString containerPort}
      CODEX_BIND=0.0.0.0
      CODEX_MAX_REQUEST_BODY_SIZE_MB=${toString cfg.maxRequestBodySizeMB}
      ADMIN_SECRET=$ADMIN_SECRET
      CODEX_API_KEYS=$CODEX_API_KEY
      CODEX_ALLOW_ANONYMOUS=${lib.boolToString cfg.allowAnonymous}

      DATABASE_DRIVER=sqlite
      DATABASE_PATH=/data/codex2api.db
      CACHE_DRIVER=memory

      CODEX_UPSTREAM_TRANSPORT=${cfg.upstreamTransport}
      CODEX_TRANSPORT_MODE=${cfg.transportMode}
      CODEX_WS_SEND_USER_AGENT=${lib.boolToString cfg.wsSendUserAgent}
      CODEX_SESSION_AFFINITY_TTL=${cfg.sessionAffinityTTL}
      CODEX_FINGERPRINT_DEBUG=${lib.boolToString cfg.fingerprintDebug}
      FAST_SCHEDULER_ENABLED=${lib.boolToString cfg.fastSchedulerEnabled}

      IMAGE_ASSET_DIR=/data/images
      BACKGROUND_ASSET_DIR=/data/backgrounds
      LOG_DIR=/app/logs
      LOG_DISABLED=${lib.boolToString cfg.logDisabled}
      SECURITY_LOG_DIR=/app/logs/security

      GIN_MODE=release
      TZ=${cfg.timeZone}
      EOF
            chmod 600 ${lib.escapeShellArg envFile}
    '';
  };

  start = pkgs.writeShellApplication {
    name = "codex2api-start";
    runtimeInputs = [pkgs.podman];
    text = ''
      exec ${podman} run \
        --name codex2api \
        --replace \
        --rm \
        --pull=newer \
        --env-file ${lib.escapeShellArg envFile} \
        -p ${lib.escapeShellArg (mkPortMapping cfg.host cfg.port containerPort)} \
        -v ${lib.escapeShellArg "${dataDir}:/data"} \
        -v ${lib.escapeShellArg "${stateDir}/logs:/app/logs"} \
        ${lib.escapeShellArg cfg.image}
    '';
  };
in {
  options.services.codex2api = {
    enable = mkEnableOption "Codex2API 用户级容器服务";

    image = mkOption {
      type = types.str;
      default = "ghcr.io/james-6-23/codex2api:latest";
      description = "Codex2API 容器镜像。";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Codex2API 发布到宿主机的监听地址。";
    };

    port = mkOption {
      type = types.port;
      default = 8410;
      description = "Codex2API 发布到宿主机的端口。";
    };

    timeZone = mkOption {
      type = types.str;
      default = "Asia/Shanghai";
      description = "Codex2API 使用的时区。";
    };

    allowAnonymous = mkOption {
      type = types.bool;
      default = false;
      description = "是否允许未配置 API Key 时匿名访问 /v1/*；仅建议临时内网测试开启。";
    };

    maxRequestBodySizeMB = mkOption {
      type = types.ints.positive;
      default = 48;
      description = "Codex2API HTTP 请求体上限，单位 MB。";
    };

    upstreamTransport = mkOption {
      type = types.enum [
        "http"
        "auto"
        "ws"
      ];
      default = "http";
      description = "Codex2API 转发到 Codex 上游时使用的传输策略。";
    };

    transportMode = mkOption {
      type = types.enum [
        "standard"
        "utls_chrome"
      ];
      default = "standard";
      description = "Codex2API HTTP TLS 指纹策略。";
    };

    wsSendUserAgent = mkOption {
      type = types.bool;
      default = false;
      description = "WebSocket 握手时是否发送 User-Agent/Version。";
    };

    sessionAffinityTTL = mkOption {
      type = types.str;
      default = "1h";
      description = "Codex 会话到账号/代理的黏性 TTL。";
    };

    fingerprintDebug = mkOption {
      type = types.bool;
      default = false;
      description = "是否输出脱敏的 Codex 指纹策略诊断日志。";
    };

    fastSchedulerEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "是否通过环境变量启用 Codex2API 快速调度器；也可以在管理后台运行时开启。";
    };

    logDisabled = mkOption {
      type = types.bool;
      default = false;
      description = "是否禁用文件型错误日志与安全审计日志。";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "services.codex2api 依赖 systemd user services 和 Podman，只能在 Linux 上启用。";
      }
    ];

    xdg.enable = true;

    home.packages = [pkgs.podman];

    systemd.user.startServices = "sd-switch";

    systemd.user.services = {
      codex2api-init = {
        Unit = {
          Description = "初始化 Codex2API 用户配置与数据目录";
          After = ["network.target"];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${init}/bin/codex2api-init";
          RemainAfterExit = true;
        };
      };

      codex2api = {
        Unit = {
          Description = "Codex2API 用户级服务";
          Requires = ["codex2api-init.service"];
          After = [
            "network.target"
            "codex2api-init.service"
          ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${start}/bin/codex2api-start";
          ExecStop = "${podman} stop --ignore --time 20 codex2api";
          Restart = "always";
          RestartSec = 3;
        };

        Install.WantedBy = ["default.target"];
      };
    };
  };
}
