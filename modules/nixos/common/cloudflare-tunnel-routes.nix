{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.cloudflareTunnelDirectRoutes;

  inherit (lib) mkEnableOption mkIf mkOption types;

  redirectPairs = lib.concatMapStringsSep "\n" (redirect: "${redirect.fake}=${redirect.real}") cfg.fakeIpRedirects;

  routeScript = pkgs.writeShellApplication {
    name = "cloudflare-tunnel-direct-routes";
    runtimeInputs = [
      pkgs.gawk
      pkgs.iptables
      pkgs.iproute2
    ];
    text = ''
      set -euo pipefail

      action="''${1:-start}"
      shift || true

      gateway=""
      interface=""

      resolve_default_route() {
        gateway="$(
          ip -4 route show default \
            | awk '$3 !~ /^198[.]18[.]/ { print $3; exit }'
        )"
        interface="$(
          ip -4 route show default \
            | awk '$3 !~ /^198[.]18[.]/ { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
        )"
      }

      configure_routes() {
        resolve_default_route

        if [[ -z "$gateway" || -z "$interface" ]]; then
          echo "cloudflare-tunnel-direct-routes: 未找到非 198.18.* 的 IPv4 默认路由" >&2
          exit 1
        fi

        for cidr in "$@"; do
          ip route replace "$cidr" via "$gateway" dev "$interface" metric 5
        done
      }

      check_routes() {
        resolve_default_route

        if [[ -z "$gateway" || -z "$interface" ]]; then
          return 1
        fi

        for cidr in "$@"; do
          if ! ip route show "$cidr" | awk -v gw="$gateway" -v dev="$interface" '
            $0 ~ ("via " gw) && $0 ~ ("dev " dev) { found = 1 }
            END { exit(found ? 0 : 1) }
          '; then
            return 1
          fi
        done
      }

      configure_nat() {
        iptables -t nat -N CLOUDFLARED_EDGE 2>/dev/null || true
        iptables -t nat -F CLOUDFLARED_EDGE

        if ! iptables -t nat -C OUTPUT -p tcp --dport 7844 -j CLOUDFLARED_EDGE 2>/dev/null; then
          iptables -t nat -A OUTPUT -p tcp --dport 7844 -j CLOUDFLARED_EDGE
        fi

        while IFS='=' read -r fakeTarget realIp; do
          if [[ -z "$fakeTarget" || -z "$realIp" ]]; then
            continue
          fi

          if [[ "$fakeTarget" != */* ]]; then
            fakeTarget="$fakeTarget/32"
          fi

          iptables -t nat -A CLOUDFLARED_EDGE \
            -p tcp -d "$fakeTarget" --dport 7844 \
            -j DNAT --to-destination "$realIp:7844"
        done <<'EOF'
      ${redirectPairs}
      EOF
      }

      check_nat() {
        iptables -t nat -C OUTPUT -p tcp --dport 7844 -j CLOUDFLARED_EDGE 2>/dev/null || return 1

        while IFS='=' read -r fakeTarget realIp; do
          if [[ -z "$fakeTarget" || -z "$realIp" ]]; then
            continue
          fi

          if [[ "$fakeTarget" != */* ]]; then
            fakeTarget="$fakeTarget/32"
          fi

          if ! iptables -t nat -C CLOUDFLARED_EDGE \
            -p tcp -d "$fakeTarget" --dport 7844 \
            -j DNAT --to-destination "$realIp:7844" 2>/dev/null; then
            return 1
          fi
        done <<'EOF'
      ${redirectPairs}
      EOF
      }

      remove_nat() {
        iptables -t nat -D OUTPUT -p tcp --dport 7844 -j CLOUDFLARED_EDGE 2>/dev/null || true
        iptables -t nat -F CLOUDFLARED_EDGE 2>/dev/null || true
        iptables -t nat -X CLOUDFLARED_EDGE 2>/dev/null || true
      }

      case "$action" in
        start)
          configure_routes "$@"
          configure_nat
          ;;
        check)
          check_routes "$@" && check_nat
          ;;
        stop)
          remove_nat

          for cidr in "$@"; do
            ip route del "$cidr" 2>/dev/null || true
          done
          ;;
        *)
          echo "cloudflare-tunnel-direct-routes: 用法为 start|check|stop [cidr...]" >&2
          exit 1
          ;;
      esac
    '';
  };

  watchScript = pkgs.writeShellApplication {
    name = "cloudflare-tunnel-direct-routes-watch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iproute2
    ];
    text = ''
      set -euo pipefail

      refresh_routes() {
        if ! ${routeScript}/bin/cloudflare-tunnel-direct-routes check "$@"; then
          ${routeScript}/bin/cloudflare-tunnel-direct-routes start "$@"
        fi
      }

      debounce_pid=""

      cleanup() {
        if [[ -n "''${debounce_pid:-}" ]]; then
          kill "$debounce_pid" 2>/dev/null || true
          wait "$debounce_pid" 2>/dev/null || true
        fi

        ${routeScript}/bin/cloudflare-tunnel-direct-routes stop "$@" || true
      }

      trap 'cleanup "$@"' EXIT INT TERM

      refresh_routes "$@"

      while IFS= read -r _event; do
        if [[ -n "''${debounce_pid:-}" ]]; then
          kill "$debounce_pid" 2>/dev/null || true
        fi

        (sleep 1; refresh_routes "$@") &
        debounce_pid=$!
      done < <(${pkgs.iproute2}/bin/ip monitor route link addr)
    '';
  };
in {
  options.services.cloudflareTunnelDirectRoutes = {
    enable = mkEnableOption "Cloudflare Tunnel edge 直连路由";

    cidrs = mkOption {
      type = types.listOf types.str;
      default = [
        "198.41.192.0/24"
        "198.41.200.0/24"
      ];
      description = "需要绕过本机 fake-IP/TUN 默认路由、直连物理 LAN 的 Cloudflare Tunnel edge IPv4 网段。";
    };

    hosts = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {
        "region1.v2.argotunnel.com" = [
          "198.41.192.167"
          "198.41.192.67"
          "198.41.192.57"
          "198.41.192.107"
          "198.41.192.27"
          "198.41.192.7"
          "198.41.192.227"
          "198.41.192.47"
          "198.41.192.37"
          "198.41.192.77"
        ];
        "region2.v2.argotunnel.com" = [
          "198.41.200.13"
          "198.41.200.193"
          "198.41.200.33"
          "198.41.200.233"
          "198.41.200.53"
          "198.41.200.63"
          "198.41.200.113"
          "198.41.200.73"
          "198.41.200.43"
          "198.41.200.23"
        ];
      };
      description = "Cloudflare Tunnel edge 域名的固定解析，用于绕过本机 fake-IP DNS。";
    };

    fakeIpRedirects = mkOption {
      type = types.listOf (types.submodule {
        options = {
          fake = mkOption {
            type = types.str;
            description = "需要改写的 fake-IP 地址或 CIDR。未写掩码时按 /32 处理。";
          };

          real = mkOption {
            type = types.str;
            description = "实际连接的 Cloudflare Tunnel edge IPv4 地址。";
          };
        };
      });
      default = [
        {
          fake = "198.18.0.103";
          real = "198.41.192.167";
        }
        {
          fake = "198.18.1.12";
          real = "198.41.200.13";
        }
        {
          fake = "198.18.0.0/16";
          real = "198.41.192.167";
        }
      ];
      description = "Cloudflare Tunnel 当前解析出的 fake-IP 到真实 Cloudflare edge IP 的改写。";
    };
  };

  config = mkIf cfg.enable {
    networking.hosts = lib.listToAttrs (
      lib.flatten (
        lib.mapAttrsToList (
          hostname: addresses:
            map (address: lib.nameValuePair address [hostname]) addresses
        )
        cfg.hosts
      )
    );

    systemd.services.cloudflare-tunnel-direct-routes = {
      description = "监控并补写 Cloudflare Tunnel edge 直连路由";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs (["${watchScript}/bin/cloudflare-tunnel-direct-routes-watch"] ++ cfg.cidrs);
        ExecStop = lib.escapeShellArgs (["${routeScript}/bin/cloudflare-tunnel-direct-routes" "stop"] ++ cfg.cidrs);
        Restart = "always";
        RestartSec = 2;
      };
    };
  };
}
