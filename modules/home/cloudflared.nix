{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.cloudflaredTunnel;

  inherit (lib) mkEnableOption mkIf mkOption types;

  edgeBindAddress =
    if cfg.edgeBindAddress == null
    then ""
    else cfg.edgeBindAddress;

  tunnelBaseArgs =
    [
      (lib.getExe cfg.package)
      "tunnel"
      "--no-autoupdate"
      "--loglevel"
      cfg.logLevel
      "--protocol"
      cfg.protocol
    ]
    ++ lib.optionals (cfg.edgeIpVersion != null) [
      "--edge-ip-version"
      cfg.edgeIpVersion
    ]
    ++ lib.optionals (cfg.metrics != null) [
      "--metrics"
      cfg.metrics
    ];

  dnsResolverArgs =
    lib.concatMap (resolver: [
      "--dns-resolver-addrs"
      resolver
    ])
    cfg.dnsResolverAddrs;

  runArgs =
    [
      "run"
    ]
    ++ dnsResolverArgs
    ++ [
      "--token-file"
      cfg.tokenFile
    ];

  runner = pkgs.writeShellApplication {
    name = "cloudflared-tunnel-run";
    runtimeInputs = [
      pkgs.gawk
      pkgs.iproute2
    ];
    text = ''
      set -euo pipefail

      edgeBindAddress=${lib.escapeShellArg edgeBindAddress}
      edgeBindArgs=()

      if [[ "$edgeBindAddress" == "auto" ]]; then
        for _ in $(seq 1 30); do
          edgeBindAddress="$(
            ip -4 route get ${lib.escapeShellArg cfg.edgeBindProbeAddress} \
              | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }'
          )"

          if [[ -n "$edgeBindAddress" && "$edgeBindAddress" != 198.18.* ]]; then
            break
          fi

          sleep 1
        done

        if [[ -z "$edgeBindAddress" || "$edgeBindAddress" == 198.18.* ]]; then
          echo "cloudflared-tunnel-run: 无法从到 ${cfg.edgeBindProbeAddress} 的路由中推导非 198.18.* 的 edge-bind-address" >&2
          exit 1
        fi
      fi

      if [[ -n "$edgeBindAddress" ]]; then
        edgeBindArgs=(--edge-bind-address "$edgeBindAddress")
      fi

      exec ${lib.escapeShellArgs tunnelBaseArgs} "''${edgeBindArgs[@]}" ${lib.escapeShellArgs runArgs}
    '';
  };
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

    protocol = mkOption {
      type = types.enum [
        "auto"
        "http2"
        "quic"
      ];
      default = "http2";
      description = "cloudflared 连接 Cloudflare edge 时使用的协议。当前网络路径下 QUIC 不稳定，默认固定为 http2。";
    };

    edgeIpVersion = mkOption {
      type = types.nullOr (types.enum [
        "auto"
        "4"
        "6"
      ]);
      default = "4";
      description = "cloudflared 连接 Cloudflare edge 时使用的 IP 版本；null 表示使用 cloudflared 默认值。";
    };

    edgeBindAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "cloudflared 连接 Cloudflare edge 时绑定的本机出口 IP；设为 auto 时运行时从路由推导；null 表示交给操作系统选择。";
    };

    edgeBindProbeAddress = mkOption {
      type = types.str;
      default = "198.41.192.167";
      description = "edgeBindAddress = auto 时用于推导本机出站源地址的 Cloudflare Tunnel edge IPv4。";
    };

    dnsResolverAddrs = mkOption {
      type = types.listOf types.str;
      default = [
        "1.1.1.1:53"
        "1.0.0.1:53"
      ];
      description = "cloudflared 解析 Cloudflare edge 域名时使用的 DNS resolver，格式必须为 ip:port。";
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
        Wants = [
          "cloudflare-tunnel-direct-routes.service"
          "network-online.target"
        ];
        After = [
          "cloudflare-tunnel-direct-routes.service"
          "network-online.target"
        ];
      };

      Service = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/test -s ${lib.escapeShellArg cfg.tokenFile}";
        ExecStart = "${runner}/bin/cloudflared-tunnel-run";
        Restart = "always";
        RestartSec = 5;
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
