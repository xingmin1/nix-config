{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.sub2api;

  inherit (lib) mkEnableOption mkIf mkOption types;

  podman = lib.getExe pkgs.podman;

  name = "sub2api";
  configDir = "${config.xdg.configHome}/${name}";
  dataDir = "${config.xdg.dataHome}/${name}";
  envFile = "${configDir}/env";
  networkName = name;
  containerPort = 8080;

  mkPortMapping = host: hostPort: containerPort: "${host}:${toString hostPort}:${toString containerPort}";

  mkContainerService = {
    description,
    execStart,
    execStop,
    extraUnit ? {},
  }: {
    Unit =
      {
        Description = description;
        After = ["network.target"];
      }
      // extraUnit;

    Service = {
      Type = "simple";
      ExecStart = execStart;
      ExecStop = execStop;
      Restart = "always";
      RestartSec = 3;
    };

    Install.WantedBy = ["default.target"];
  };

  init = pkgs.writeShellApplication {
    name = "sub2api-init";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.openssl
      pkgs.podman
    ];
    text = ''
            set -euo pipefail

            install -d -m 700 \
              ${lib.escapeShellArg configDir} \
              ${lib.escapeShellArg "${dataDir}/data"} \
              ${lib.escapeShellArg "${dataDir}/postgres"} \
              ${lib.escapeShellArg "${dataDir}/redis"}

            if [ ! -f ${lib.escapeShellArg envFile} ]; then
              umask 077
              postgres_password="$(openssl rand -hex 32)"
              admin_password="$(openssl rand -hex 16)"
              jwt_secret="$(openssl rand -hex 32)"
              totp_encryption_key="$(openssl rand -hex 32)"

      cat > ${lib.escapeShellArg envFile} <<EOF
      BIND_HOST=${cfg.host}
      SERVER_PORT=${toString containerPort}
      SERVER_MODE=release
      RUN_MODE=${cfg.runMode}
      TZ=${cfg.timeZone}

      POSTGRES_USER=sub2api
      POSTGRES_PASSWORD=$postgres_password
      POSTGRES_DB=sub2api

      DATABASE_HOST=sub2api-postgres
      DATABASE_PORT=5432
      DATABASE_USER=sub2api
      DATABASE_PASSWORD=$postgres_password
      DATABASE_DBNAME=sub2api
      DATABASE_SSLMODE=disable
      DATABASE_MAX_OPEN_CONNS=50
      DATABASE_MAX_IDLE_CONNS=10
      DATABASE_CONN_MAX_LIFETIME_MINUTES=30
      DATABASE_CONN_MAX_IDLE_TIME_MINUTES=5

      REDIS_HOST=sub2api-redis
      REDIS_PORT=6379
      REDIS_PASSWORD=
      REDIS_DB=0
      REDIS_POOL_SIZE=1024
      REDIS_MIN_IDLE_CONNS=10
      REDIS_ENABLE_TLS=false

      ADMIN_EMAIL=admin@sub2api.local
      ADMIN_PASSWORD=$admin_password
      JWT_SECRET=$jwt_secret
      JWT_EXPIRE_HOUR=24
      TOTP_ENCRYPTION_KEY=$totp_encryption_key

      SECURITY_URL_ALLOWLIST_ENABLED=false
      SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=false
      SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=false
      UPDATE_PROXY_URL=
      EOF
            fi

            if grep -q '^RUN_MODE=' ${lib.escapeShellArg envFile}; then
              sed -i -E ${lib.escapeShellArg "s#^RUN_MODE=.*#RUN_MODE=${cfg.runMode}#"} ${lib.escapeShellArg envFile}
            else
              printf '\nRUN_MODE=%s\n' ${lib.escapeShellArg cfg.runMode} >> ${lib.escapeShellArg envFile}
            fi

            ${podman} network exists ${lib.escapeShellArg networkName} >/dev/null 2>&1 \
              || ${podman} network create ${lib.escapeShellArg networkName} >/dev/null
    '';
  };

  postgresStart = pkgs.writeShellApplication {
    name = "sub2api-postgres-start";
    runtimeInputs = [pkgs.podman];
    text = ''
      exec ${podman} run \
        --name sub2api-postgres \
        --replace \
        --rm \
        --pull=newer \
        --network ${lib.escapeShellArg networkName} \
        --ulimit nofile=100000:100000 \
        --env-file ${lib.escapeShellArg envFile} \
        -e PGDATA=/var/lib/postgresql/data \
        -v ${lib.escapeShellArg "${dataDir}/postgres:/var/lib/postgresql/data"} \
        ${lib.escapeShellArg cfg.postgresImage}
    '';
  };

  redisStart = pkgs.writeShellApplication {
    name = "sub2api-redis-start";
    runtimeInputs = [pkgs.podman];
    text = ''
      exec ${podman} run \
        --name sub2api-redis \
        --replace \
        --rm \
        --pull=newer \
        --network ${lib.escapeShellArg networkName} \
        --ulimit nofile=100000:100000 \
        --env-file ${lib.escapeShellArg envFile} \
        -v ${lib.escapeShellArg "${dataDir}/redis:/data"} \
        ${lib.escapeShellArg cfg.redisImage} \
        sh -c 'exec redis-server --save 60 1 --appendonly yes --appendfsync everysec ''${REDIS_PASSWORD:+--requirepass "$REDIS_PASSWORD"}'
    '';
  };

  start = pkgs.writeShellApplication {
    name = "sub2api-start";
    runtimeInputs = [pkgs.podman];
    text = ''
      exec ${podman} run \
        --name sub2api \
        --replace \
        --rm \
        --pull=newer \
        --network ${lib.escapeShellArg networkName} \
        --ulimit nofile=100000:100000 \
        --env-file ${lib.escapeShellArg envFile} \
        -e AUTO_SETUP=true \
        -e SERVER_HOST=0.0.0.0 \
        -e SERVER_PORT=${toString containerPort} \
        -p ${lib.escapeShellArg (mkPortMapping cfg.host cfg.port containerPort)} \
        -v ${lib.escapeShellArg "${dataDir}/data:/app/data"} \
        ${lib.escapeShellArg cfg.image}
    '';
  };
in {
  options.services.sub2api = {
    enable = mkEnableOption "Sub2API 用户级容器服务";

    image = mkOption {
      type = types.str;
      default = "weishaw/sub2api:latest";
      description = "Sub2API 主服务容器镜像。";
    };

    postgresImage = mkOption {
      type = types.str;
      default = "postgres:18-alpine";
      description = "Sub2API PostgreSQL 容器镜像。";
    };

    redisImage = mkOption {
      type = types.str;
      default = "redis:8-alpine";
      description = "Sub2API Redis 容器镜像。";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Sub2API 发布到宿主机的监听地址。";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Sub2API 发布到宿主机的端口。";
    };

    timeZone = mkOption {
      type = types.str;
      default = "Asia/Shanghai";
      description = "传递给 Sub2API 容器的时区。";
    };

    runMode = mkOption {
      type = types.enum [
        "standard"
        "simple"
      ];
      default = "standard";
      description = "Sub2API 运行模式；simple 会隐藏 SaaS 功能并跳过计费/余额校验。";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "services.sub2api 依赖 systemd user services 和 Podman，只能在 Linux 上启用。";
      }
    ];

    xdg.enable = true;

    home.packages = [pkgs.podman];

    systemd.user.startServices = "sd-switch";

    systemd.user.services = {
      sub2api-init = {
        Unit = {
          Description = "初始化 Sub2API 用户目录与容器网络";
          After = ["network.target"];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${init}/bin/sub2api-init";
          RemainAfterExit = true;
        };
      };

      sub2api-postgres = mkContainerService {
        description = "Sub2API PostgreSQL";
        execStart = "${postgresStart}/bin/sub2api-postgres-start";
        execStop = "${podman} stop --ignore --time 20 sub2api-postgres";
        extraUnit = {
          Requires = ["sub2api-init.service"];
          After = [
            "network.target"
            "sub2api-init.service"
          ];
        };
      };

      sub2api-redis = mkContainerService {
        description = "Sub2API Redis";
        execStart = "${redisStart}/bin/sub2api-redis-start";
        execStop = "${podman} stop --ignore --time 20 sub2api-redis";
        extraUnit = {
          Requires = ["sub2api-init.service"];
          After = [
            "network.target"
            "sub2api-init.service"
          ];
        };
      };

      sub2api = mkContainerService {
        description = "Sub2API 用户级服务";
        execStart = "${start}/bin/sub2api-start";
        execStop = "${podman} stop --ignore --time 20 sub2api";
        extraUnit = {
          Requires = [
            "sub2api-postgres.service"
            "sub2api-redis.service"
          ];
          After = [
            "sub2api-postgres.service"
            "sub2api-redis.service"
          ];
        };
      };
    };
  };
}
