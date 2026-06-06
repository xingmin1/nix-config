{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.cliProxyApi;

  inherit (lib) mkEnableOption mkIf mkOption types;

  podman = lib.getExe pkgs.podman;

  name = "cli-proxy-api";
  configDir = "${config.xdg.configHome}/${name}";
  dataDir = "${config.xdg.dataHome}/${name}";
  stateDir = "${config.xdg.stateHome}/${name}";
  configFile = "${configDir}/config.yaml";
  credentialsFile = "${configDir}/credentials.env";
  containerPort = 8317;
  containerAuthDir = "/root/.cli-proxy-api";

  mkPortMapping = host: hostPort: containerPort: "${host}:${toString hostPort}:${toString containerPort}";

  init = pkgs.writeShellApplication {
    name = "cli-proxy-api-init";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.openssl
      pkgs.podman
    ];
    text = ''
            set -euo pipefail

            install -d -m 700 \
              ${lib.escapeShellArg configDir} \
              ${lib.escapeShellArg "${dataDir}/auths"} \
              ${lib.escapeShellArg "${stateDir}/logs"}

            if [ ! -f ${lib.escapeShellArg credentialsFile} ]; then
              umask 077
              api_key=""
              if [ -f ${lib.escapeShellArg configFile} ]; then
                api_key="$(awk -F '"' '/- "cpapi-/ { print $2; exit }' ${lib.escapeShellArg configFile})"
              fi

              if [ -z "$api_key" ]; then
                api_key="cpapi-$(openssl rand -hex 24)"
              fi

              management_key="$(openssl rand -hex 32)"

              cat > ${lib.escapeShellArg credentialsFile} <<EOF
      CLI_PROXY_API_KEY=$api_key
      CLI_PROXY_API_MANAGEMENT_KEY=$management_key
      EOF

              if [ -f ${lib.escapeShellArg configFile} ]; then
                sed -i -E "s#^([[:space:]]*secret-key: ).*#\1\"$management_key\"#" ${lib.escapeShellArg configFile}
              fi
            fi

            # shellcheck source=/dev/null
            . ${lib.escapeShellArg credentialsFile}

            remote_management_enabled=${lib.boolToString cfg.allowRemoteManagement}
            usage_statistics_enabled=${lib.boolToString cfg.usageStatisticsEnabled}

            if [ ! -f ${lib.escapeShellArg configFile} ]; then
              umask 077

              cat > ${lib.escapeShellArg configFile} <<EOF
      host: "0.0.0.0"
      port: ${toString containerPort}

      tls:
        enable: false
        cert: ""
        key: ""

      remote-management:
        allow-remote: $remote_management_enabled
        secret-key: "$CLI_PROXY_API_MANAGEMENT_KEY"
        disable-control-panel: false
        panel-github-repository: "https://github.com/router-for-me/Cli-Proxy-API-Management-Center"

      auth-dir: "${containerAuthDir}"

      api-keys:
        - "$CLI_PROXY_API_KEY"

      debug: false
      pprof:
        enable: false
        addr: "127.0.0.1:8316"

      commercial-mode: false
      logging-to-file: true
      logs-max-total-size-mb: 512
      error-logs-max-files: 10
      usage-statistics-enabled: $usage_statistics_enabled
      redis-usage-queue-retention-seconds: ${toString cfg.redisUsageQueueRetentionSeconds}
      proxy-url: ""
      force-model-prefix: false
      passthrough-headers: false
      request-retry: 3
      max-retry-credentials: 0
      max-retry-interval: 30
      disable-cooling: false
      disable-image-generation: false
      ws-auth: true
      enable-gemini-cli-endpoint: false
      nonstream-keepalive-interval: 0

      quota-exceeded:
        switch-project: true
        switch-preview-model: true
        antigravity-credits: true

      routing:
        strategy: "round-robin"
        session-affinity: false
        session-affinity-ttl: "1h"

      codex:
        identity-confuse: false
      EOF
            fi

            sed -i -E "s#^([[:space:]]*allow-remote: ).*#\1$remote_management_enabled#" ${lib.escapeShellArg configFile}
            sed -i -E "s#^([[:space:]]*auth-dir: ).*#\1\"${containerAuthDir}\"#" ${lib.escapeShellArg configFile}
            sed -i -E "s#^([[:space:]]*usage-statistics-enabled: ).*#\1$usage_statistics_enabled#" ${lib.escapeShellArg configFile}
            sed -i -E "s#^([[:space:]]*redis-usage-queue-retention-seconds: ).*#\1${toString cfg.redisUsageQueueRetentionSeconds}#" ${lib.escapeShellArg configFile}

            if grep -q -E '^[[:space:]]*secret-key:[[:space:]]*""[[:space:]]*$' ${lib.escapeShellArg configFile}; then
              sed -i -E "s#^([[:space:]]*secret-key: ).*#\1\"$CLI_PROXY_API_MANAGEMENT_KEY\"#" ${lib.escapeShellArg configFile}
            fi

            ${podman} network exists ${lib.escapeShellArg cfg.networkName} >/dev/null 2>&1 \
              || ${podman} network create ${lib.escapeShellArg cfg.networkName} >/dev/null
    '';
  };

  portMappings =
    [
      (mkPortMapping cfg.host cfg.port containerPort)
    ]
    ++ map (port: mkPortMapping cfg.host port port) cfg.callbackPorts;

  start = pkgs.writeShellApplication {
    name = "cli-proxy-api-start";
    runtimeInputs = [pkgs.podman];
    text = ''
      exec ${podman} run \
        --name cli-proxy-api \
        --replace \
        --rm \
        --pull=newer \
        --network ${lib.escapeShellArg cfg.networkName} \
        ${lib.concatMapStringsSep " \\\n  " (port: "-p ${lib.escapeShellArg port}") portMappings} \
        -e TZ=${lib.escapeShellArg cfg.timeZone} \
        -v ${lib.escapeShellArg "${configFile}:/CLIProxyAPI/config.yaml"} \
        -v ${lib.escapeShellArg "${dataDir}/auths:/root/.cli-proxy-api"} \
        -v ${lib.escapeShellArg "${stateDir}/logs:/CLIProxyAPI/logs"} \
        ${lib.escapeShellArg cfg.image}
    '';
  };
in {
  options.services.cliProxyApi = {
    enable = mkEnableOption "CLIProxyAPI 用户级容器服务";

    image = mkOption {
      type = types.str;
      default = "eceasy/cli-proxy-api:latest";
      description = "CLIProxyAPI 容器镜像。";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "CLIProxyAPI 发布到宿主机的监听地址。";
    };

    port = mkOption {
      type = types.port;
      default = 8317;
      description = "CLIProxyAPI 主服务发布到宿主机的端口。";
    };

    callbackPorts = mkOption {
      type = types.listOf types.port;
      default = [
        8085
        1455
        54545
        51121
        11451
      ];
      description = "CLIProxyAPI OAuth 回调等辅助端口。";
    };

    timeZone = mkOption {
      type = types.str;
      default = "Asia/Shanghai";
      description = "传递给 CLIProxyAPI 容器的时区。";
    };

    networkName = mkOption {
      type = types.str;
      default = "cpa-net";
      description = "CLIProxyAPI 容器加入的 Podman 网络名称；用于让相关用户态容器通过容器名互访。";
    };

    allowRemoteManagement = mkOption {
      type = types.bool;
      default = true;
      description = "是否允许 CLIProxyAPI Management API 接受非 localhost 客户端访问；Podman 端口转发场景通常需要启用。";
    };

    usageStatisticsEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "是否开启 CLIProxyAPI 内存 usage queue，供 CPA Usage Keeper 消费。";
    };

    redisUsageQueueRetentionSeconds = mkOption {
      type = types.ints.between 1 3600;
      default = 60;
      description = "CLIProxyAPI usage queue 记录保留秒数，当前上游配置最大值为 3600。";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "services.cliProxyApi 依赖 systemd user services 和 Podman，只能在 Linux 上启用。";
      }
    ];

    xdg.enable = true;

    home.packages = [pkgs.podman];

    systemd.user.startServices = "sd-switch";

    systemd.user.services = {
      cli-proxy-api-init = {
        Unit = {
          Description = "初始化 CLIProxyAPI 用户配置与数据目录";
          After = ["network.target"];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${init}/bin/cli-proxy-api-init";
          RemainAfterExit = true;
        };
      };

      cli-proxy-api = {
        Unit = {
          Description = "CLIProxyAPI 用户级服务";
          Requires = ["cli-proxy-api-init.service"];
          After = [
            "network.target"
            "cli-proxy-api-init.service"
          ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${start}/bin/cli-proxy-api-start";
          ExecStop = "${podman} stop --ignore --time 20 cli-proxy-api";
          Restart = "always";
          RestartSec = 3;
        };

        Install.WantedBy = ["default.target"];
      };
    };
  };
}
