{
  config,
  flake,
  lib,
  pkgs,
  ...
}: let
  jcodePackage = flake.inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.jcode;

  protectedServiceConfig = {
    ManagedOOMPreference = "avoid";
    OOMPolicy = "kill";
    OOMScoreAdjust = -200;
    Slice = "ai.slice";
  };

  scopedWorkload = pkgs.writeShellApplication {
    name = "scoped-workload";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      if [[ $# -lt 2 ]]; then
        echo "用法: scoped-workload <build|jcode|protected> <命令> [参数...]" >&2
        exit 2
      fi

      workloadClass="$1"
      shift

      case "$workloadClass" in
        build)
          slice="build.slice"
          preference="none"
          command=(choom -n 500 -- "$@")
          ;;
        jcode)
          slice="jcode.slice"
          preference="none"
          command=("$@")
          ;;
        protected)
          slice="ai.slice"
          preference="avoid"
          command=("$@")
          ;;
        *)
          echo "未知工作负载类型: $workloadClass" >&2
          exit 2
          ;;
      esac

      currentCgroup="$(cut -d: -f3 /proc/self/cgroup)"
      if [[ "$currentCgroup" == *"/$slice/"* || "$currentCgroup" == *"/$slice" ]]; then
        exec "''${command[@]}"
      fi

      if ! systemctl --user show-environment >/dev/null; then
        echo "无法连接 systemd 用户管理器，拒绝在 cgroup 防护之外启动工作负载。" >&2
        exit 1
      fi

      exec systemd-run \
        --user \
        --scope \
        --same-dir \
        --collect \
        --quiet \
        --slice="$slice" \
        --property=OOMPolicy=kill \
        --property=ManagedOOMPreference="$preference" \
        -- "''${command[@]}"
    '';
  };

  # Codex 工具 shell 不加载交互式 alias，因此隔离必须落实到同名可执行入口。
  mkBuildWrapper = name: binary:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [scopedWorkload];
      text = ''
        exec ${scopedWorkload}/bin/scoped-workload build ${lib.escapeShellArg binary} "$@"
      '';
    };

  astBroPackage = flake.inputs.ast-bro.packages.${pkgs.stdenv.hostPlatform.system}.default;
  astBroWrapper = mkBuildWrapper "ast-bro" "${astBroPackage}/bin/ast-bro";
  sbWrapper = mkBuildWrapper "sb" "${astBroPackage}/bin/sb";

  scopedJcode = pkgs.writeShellApplication {
    name = "jcode";
    runtimeInputs = [scopedWorkload];
    text = ''
      exec scoped-workload jcode ${lib.getExe jcodePackage} "$@"
    '';
  };
in {
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [
      scopedWorkload
      scopedJcode
      astBroWrapper
      sbWrapper
    ];

    # 限制单次 Cargo 的内部并发，避免一个构建再次同时启动数十个重型链接器。
    home.file.".cargo/config.toml".text = ''
      [build]
      jobs = 6
    '';

    home.shellAliases = {
      cargo = "scoped-workload build cargo";
      codex = "scoped-workload protected codex";
      nh = "scoped-workload build nh";
      nix = "scoped-workload build nix";
      nixos-rebuild = "scoped-workload build nixos-rebuild";
    };

    systemd.user.slices = {
      ai = {
        Unit.Description = "Protected AI and connectivity workloads";
        Slice = {
          ManagedOOMPreference = "avoid";
          MemoryLow = "2G";
        };
      };

      jcode = {
        Unit.Description = "Memory-limited Jcode workloads";
        Slice = {
          MemoryMax = "80%";
        };
      };

      build = {
        Unit.Description = "Disposable development and build workloads";
        Slice = {
          ManagedOOMMemoryPressure = "kill";
          ManagedOOMMemoryPressureDurationSec = "15s";
          ManagedOOMMemoryPressureLimit = "70%";
          ManagedOOMSwap = "kill";
          MemoryMax = "80%";
          MemorySwapMax = "8G";
        };
      };
    };

    systemd.user.services = lib.mkMerge [
      (lib.mkIf config.services.codex2api.enable {
        codex2api.Service = protectedServiceConfig;
      })
      (lib.mkIf config.services.cloudflaredTunnel.enable {
        cloudflared-tunnel.Service = protectedServiceConfig;
      })
      (lib.mkIf config.services.ccConnect.enable {
        cc-connect.Service = protectedServiceConfig;
      })
      (lib.mkIf config.services.grokOpenAICompat.enable {
        grok-openai-compat.Service = protectedServiceConfig;
      })
    ];
  };
}
