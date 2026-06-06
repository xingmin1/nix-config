{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.cpaUsageKeeper;
  cliProxyCfg = config.services.cliProxyApi;

  inherit (lib) mkEnableOption mkIf mkOption types;

  podman = lib.getExe pkgs.podman;

  name = "cpa-usage-keeper";
  configDir = "${config.xdg.configHome}/${name}";
  dataDir = "${config.xdg.dataHome}/${name}";
  envFile = "${configDir}/env";
  containerPort = 8080;

  mkPortMapping = host: hostPort: containerPort: "${host}:${toString hostPort}:${toString containerPort}";

  init = pkgs.writeShellApplication {
    name = "cpa-usage-keeper-init";
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
              ${lib.escapeShellArg dataDir}

            if [ ! -f ${lib.escapeShellArg cfg.cliProxyCredentialsFile} ]; then
              echo "CLIProxyAPI credentials file is missing: ${lib.escapeShellArg cfg.cliProxyCredentialsFile}" >&2
              exit 1
            fi

            # shellcheck source=/dev/null
            . ${lib.escapeShellArg cfg.cliProxyCredentialsFile}

            if [ -z "''${CLI_PROXY_API_MANAGEMENT_KEY:-}" ]; then
              echo "CLI_PROXY_API_MANAGEMENT_KEY is empty in ${lib.escapeShellArg cfg.cliProxyCredentialsFile}" >&2
              exit 1
            fi

            if [ ! -f ${lib.escapeShellArg envFile} ]; then
              umask 077
              login_password="$(openssl rand -hex 16)"
              cat > ${lib.escapeShellArg envFile} <<EOF
      LOGIN_PASSWORD=$login_password
      EOF
            fi

            login_password="$(awk -F= '/^LOGIN_PASSWORD=/ { print substr($0, index($0, "=") + 1); exit }' ${lib.escapeShellArg envFile})"
            if [ -z "$login_password" ]; then
              login_password="$(openssl rand -hex 16)"
            fi

            upsert_env() {
              key="$1"
              value="$2"
              tmp="$(mktemp)"
              awk -v key="$key" -v value="$value" '
                BEGIN { updated = 0 }
                $0 ~ "^" key "=" {
                  print key "=" value
                  updated = 1
                  next
                }
                { print }
                END {
                  if (!updated) {
                    print key "=" value
                  }
                }
              ' ${lib.escapeShellArg envFile} > "$tmp"
              cat "$tmp" > ${lib.escapeShellArg envFile}
              rm -f "$tmp"
            }

            upsert_env CPA_BASE_URL ${lib.escapeShellArg cfg.cpaBaseUrl}
            upsert_env CPA_MANAGEMENT_KEY "$CLI_PROXY_API_MANAGEMENT_KEY"
            upsert_env APP_PORT ${lib.escapeShellArg (toString containerPort)}
            upsert_env APP_BASE_PATH ${lib.escapeShellArg cfg.basePath}
            upsert_env CPA_PUBLIC_URL ${lib.escapeShellArg cfg.cpaPublicUrl}
            upsert_env AUTH_ENABLED ${lib.escapeShellArg (lib.boolToString cfg.authEnabled)}
            upsert_env LOGIN_PASSWORD "$login_password"
            upsert_env AUTH_SESSION_TTL ${lib.escapeShellArg cfg.authSessionTTL}
            upsert_env TZ ${lib.escapeShellArg cfg.timeZone}
            upsert_env REQUEST_TIMEOUT ${lib.escapeShellArg cfg.requestTimeout}
            upsert_env TLS_SKIP_VERIFY ${lib.escapeShellArg (lib.boolToString cfg.tlsSkipVerify)}
            upsert_env QUOTA_AUTO_REFRESH_ENABLED ${lib.escapeShellArg (lib.boolToString cfg.quotaAutoRefreshEnabled)}
            upsert_env QUOTA_AUTO_REFRESH_INTERVAL ${lib.escapeShellArg cfg.quotaAutoRefreshInterval}
            upsert_env QUOTA_REFRESH_WORKER_LIMIT ${lib.escapeShellArg (toString cfg.quotaRefreshWorkerLimit)}
            upsert_env REDIS_QUEUE_ADDR ${lib.escapeShellArg cfg.redisQueueAddr}
            upsert_env REDIS_QUEUE_TLS ${lib.escapeShellArg (lib.boolToString cfg.redisQueueTls)}
            upsert_env WORK_DIR /data
            upsert_env LOG_LEVEL ${lib.escapeShellArg cfg.logLevel}
            upsert_env LOG_FILE_ENABLED ${lib.escapeShellArg (lib.boolToString cfg.logFileEnabled)}
            upsert_env LOG_RETENTION_DAYS ${lib.escapeShellArg (toString cfg.logRetentionDays)}
            upsert_env BACKUP_ENABLED ${lib.escapeShellArg (lib.boolToString cfg.backupEnabled)}
            upsert_env BACKUP_INTERVAL ${lib.escapeShellArg cfg.backupInterval}
            upsert_env BACKUP_RETENTION_DAYS ${lib.escapeShellArg (toString cfg.backupRetentionDays)}
            upsert_env TLS_ENABLED false
            chmod 600 ${lib.escapeShellArg envFile}

            ${podman} network exists ${lib.escapeShellArg cfg.networkName} >/dev/null 2>&1 \
              || ${podman} network create ${lib.escapeShellArg cfg.networkName} >/dev/null
    '';
  };

  start = pkgs.writeShellApplication {
    name = "cpa-usage-keeper-start";
    runtimeInputs = [pkgs.podman];
    text = ''
      exec ${podman} run \
        --name cpa-usage-keeper \
        --replace \
        --rm \
        --pull=newer \
        --network ${lib.escapeShellArg cfg.networkName} \
        -p ${lib.escapeShellArg (mkPortMapping cfg.host cfg.port containerPort)} \
        --env-file ${lib.escapeShellArg envFile} \
        -v ${lib.escapeShellArg "${dataDir}:/data"} \
        ${lib.escapeShellArg cfg.image}
    '';
  };
in {
  options.services.cpaUsageKeeper = {
    enable = mkEnableOption "CPA Usage Keeper 用户级容器服务";

    image = mkOption {
      type = types.str;
      default = "ghcr.io/willxup/cpa-usage-keeper:latest";
      description = "CPA Usage Keeper 容器镜像。";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "CPA Usage Keeper 发布到宿主机的监听地址。";
    };

    port = mkOption {
      type = types.port;
      default = 8400;
      description = "CPA Usage Keeper 发布到宿主机的端口。";
    };

    networkName = mkOption {
      type = types.str;
      default = cliProxyCfg.networkName;
      description = "CPA Usage Keeper 容器加入的 Podman 网络名称。";
    };

    cpaBaseUrl = mkOption {
      type = types.str;
      default = "http://cli-proxy-api:8317";
      description = "Keeper 服务端访问 CLIProxyAPI 的内部地址。";
    };

    cpaPublicUrl = mkOption {
      type = types.str;
      default = "http://${cliProxyCfg.host}:${toString cliProxyCfg.port}";
      description = "浏览器从 Keeper 返回 CPAMC 时使用的公开 CLIProxyAPI 地址。";
    };

    cliProxyCredentialsFile = mkOption {
      type = types.path;
      default = "${config.xdg.configHome}/cli-proxy-api/credentials.env";
      description = "包含 CLI_PROXY_API_MANAGEMENT_KEY 的 CLIProxyAPI 凭据文件路径。";
    };

    basePath = mkOption {
      type = types.str;
      default = "";
      description = "Keeper Web UI 子路径；空字符串表示根路径。";
    };

    authEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 Keeper 登录保护。";
    };

    authSessionTTL = mkOption {
      type = types.str;
      default = "168h";
      description = "Keeper 登录 session 有效期。";
    };

    timeZone = mkOption {
      type = types.str;
      default = "Asia/Shanghai";
      description = "CPA Usage Keeper 统计与日志使用的时区。";
    };

    requestTimeout = mkOption {
      type = types.str;
      default = "30s";
      description = "Keeper 访问 CLIProxyAPI HTTP 接口和 usage queue 的超时时间。";
    };

    tlsSkipVerify = mkOption {
      type = types.bool;
      default = false;
      description = "是否跳过 Keeper 访问 CLIProxyAPI HTTPS/TLS 时的证书验证。";
    };

    quotaAutoRefreshEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 Auth Files 限额自动刷新；仅在后台页面活跃时执行。";
    };

    quotaAutoRefreshInterval = mkOption {
      type = types.str;
      default = "5m";
      description = "Auth Files 限额自动刷新间隔。";
    };

    quotaRefreshWorkerLimit = mkOption {
      type = types.ints.between 1 100;
      default = 10;
      description = "Auth Files 限额刷新队列的最大并发数。";
    };

    redisQueueAddr = mkOption {
      type = types.str;
      default = "cli-proxy-api:8317";
      description = "CLIProxyAPI management data stream 的 Redis/RESP TCP 地址。";
    };

    redisQueueTls = mkOption {
      type = types.bool;
      default = false;
      description = "是否使用 TLS 连接 CLIProxyAPI usage queue。";
    };

    logLevel = mkOption {
      type = types.str;
      default = "info";
      description = "CPA Usage Keeper 日志级别。";
    };

    logFileEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "是否让 CPA Usage Keeper 写入持久化日志文件。";
    };

    logRetentionDays = mkOption {
      type = types.ints.unsigned;
      default = 7;
      description = "CPA Usage Keeper 日志保留天数；0 表示不自动清理。";
    };

    backupEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "是否启用 CPA Usage Keeper SQLite 备份。";
    };

    backupInterval = mkOption {
      type = types.str;
      default = "24h";
      description = "CPA Usage Keeper SQLite 备份间隔。";
    };

    backupRetentionDays = mkOption {
      type = types.ints.unsigned;
      default = 7;
      description = "CPA Usage Keeper SQLite 备份保留天数。";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "services.cpaUsageKeeper 依赖 systemd user services 和 Podman，只能在 Linux 上启用。";
      }
      {
        assertion = cliProxyCfg.enable;
        message = "services.cpaUsageKeeper 需要同时启用 services.cliProxyApi。";
      }
    ];

    xdg.enable = true;

    home.packages = [pkgs.podman];

    systemd.user.startServices = "sd-switch";

    systemd.user.services = {
      cpa-usage-keeper-init = {
        Unit = {
          Description = "初始化 CPA Usage Keeper 用户配置与数据目录";
          Requires = ["cli-proxy-api-init.service"];
          After = [
            "network.target"
            "cli-proxy-api-init.service"
          ];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${init}/bin/cpa-usage-keeper-init";
          RemainAfterExit = true;
        };
      };

      cpa-usage-keeper = {
        Unit = {
          Description = "CPA Usage Keeper 用户级服务";
          Requires = [
            "cli-proxy-api.service"
            "cpa-usage-keeper-init.service"
          ];
          After = [
            "network.target"
            "cli-proxy-api.service"
            "cpa-usage-keeper-init.service"
          ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${start}/bin/cpa-usage-keeper-start";
          ExecStop = "${podman} stop --ignore --time 20 cpa-usage-keeper";
          Restart = "always";
          RestartSec = 3;
        };

        Install.WantedBy = ["default.target"];
      };
    };
  };
}
