{
  config,
  flake,
  lib,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  homeDirectory = config.home.homeDirectory;
  agentWrapperDirectory = "${homeDirectory}/.local/share/nix-config/agent-bin";
  vscodeMachineSettings = "${homeDirectory}/.vscode-server/data/Machine/settings.json";
  codexSubagentInstructions = "${config.home.homeDirectory}/.codex/instructions/subagents.md";

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
        echo "用法: scoped-workload <analysis|build|claude|codex|grok|jcode|protected> <命令> [参数...]" >&2
        exit 2
      fi

      workloadClass="$1"
      shift
      slice=""
      preference="none"
      memoryMax=""
      memorySwapMax=""
      command=()

      case "$workloadClass" in
        analysis)
          slice="analysis.slice"
          command=(choom -n 500 -- "$@")
          ;;
        build)
          slice="build.slice"
          command=(choom -n 500 -- "$@")
          ;;
        claude)
          slice="ai-claude.slice"
          memoryMax="45%"
          memorySwapMax="4G"
          command=("$@")
          ;;
        codex)
          slice="ai-codex.slice"
          memoryMax="45%"
          memorySwapMax="4G"
          command=("$@")
          ;;
        grok)
          slice="ai-grok.slice"
          memoryMax="45%"
          memorySwapMax="4G"
          command=("$@")
          ;;
        jcode)
          slice="ai-jcode.slice"
          memoryMax="60%"
          memorySwapMax="8G"
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

      systemdRunProperties=(
        --property=OOMPolicy=kill
        --property=ManagedOOMPreference="$preference"
      )
      if [[ -n "$memoryMax" ]]; then
        systemdRunProperties+=(
          --property=ManagedOOMMemoryPressure=kill
          --property=ManagedOOMMemoryPressureDurationSec=15s
          --property=ManagedOOMMemoryPressureLimit=70%
          --property=ManagedOOMSwap=kill
          --property=MemoryMax="$memoryMax"
          --property=MemorySwapMax="$memorySwapMax"
        )
      fi

      exec systemd-run \
        --user \
        --scope \
        --same-dir \
        --collect \
        --quiet \
        --slice="$slice" \
        "''${systemdRunProperties[@]}" \
        -- "''${command[@]}"
    '';
  };

  mkScopedWrapper = workloadClass: name: binary:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [scopedWorkload];
      text = ''
        exec ${scopedWorkload}/bin/scoped-workload ${workloadClass} ${lib.escapeShellArg binary} "$@"
      '';
    };

  astBroPackage = flake.inputs.ast-bro.packages.${system}.default;
  astBroWrapper = mkScopedWrapper "analysis" "ast-bro" "${astBroPackage}/bin/ast-bro";
  sbWrapper = mkScopedWrapper "analysis" "sb" "${astBroPackage}/bin/sb";

  codexPackage = flake.inputs.self.packages.${system}.codex;
  configuredCodex = pkgs.symlinkJoin {
    name = "codex-configured";
    paths = [codexPackage];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram "$out/bin/codex" \
        --run 'if [ -r "${codexSubagentInstructions}" ]; then set -- -c "developer_instructions=$(${pkgs.coreutils}/bin/cat "${codexSubagentInstructions}")" "$@"; fi'
    '';
  };
  codexWrapper = mkScopedWrapper "codex" "codex" "${configuredCodex}/bin/codex";
  codexCodeModeHostWrapper = mkScopedWrapper "codex" "codex-code-mode-host" "${codexPackage}/bin/codex-code-mode-host";
  codexAgentPackage = pkgs.symlinkJoin {
    name = "codex-agent";
    paths = [configuredCodex];
    postBuild = ''
      rm -f "$out/bin/codex" "$out/bin/codex-code-mode-host"
      ln -s ${codexWrapper}/bin/codex "$out/bin/codex"
      ln -s ${codexCodeModeHostWrapper}/bin/codex-code-mode-host "$out/bin/codex-code-mode-host"
    '';
  };

  codexAcpPackage = flake.inputs.llm-agents.packages.${system}.codex-acp;
  codexAcpWrapper = pkgs.writeShellApplication {
    name = "codex-acp";
    runtimeInputs = [scopedWorkload];
    text = ''
      export CODEX_PATH=${lib.escapeShellArg "${configuredCodex}/bin/codex"}
      exec ${scopedWorkload}/bin/scoped-workload codex ${lib.escapeShellArg "${codexAcpPackage}/bin/codex-acp"} "$@"
    '';
  };

  claudeWrapper = mkScopedWrapper "claude" "claude" "${flake.inputs.llm-agents.packages.${system}.claude-code}/bin/claude";

  grokPackage = flake.inputs.llm-agents.packages.${system}.grok;
  configuredGrok = pkgs.symlinkJoin {
    name = "grok-configured";
    paths = [grokPackage];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      for program in grok agent; do
        wrapProgram "$out/bin/$program" \
          --add-flags "--always-approve" \
          --set GROK_CODEX2API_KEY local-compat-proxy
      done
    '';
  };
  grokWrapper = mkScopedWrapper "grok" "grok" "${configuredGrok}/bin/grok";
  grokAgentWrapper = mkScopedWrapper "grok" "agent" "${configuredGrok}/bin/agent";
  grokAgentPackage = pkgs.symlinkJoin {
    name = "grok-agent";
    paths = [configuredGrok];
    postBuild = ''
      rm -f "$out/bin/grok" "$out/bin/agent"
      ln -s ${grokWrapper}/bin/grok "$out/bin/grok"
      ln -s ${grokAgentWrapper}/bin/agent "$out/bin/agent"
    '';
  };

  jcodePackage = flake.inputs.self.packages.${system}.jcode;
  scopedJcode = mkScopedWrapper "jcode" "jcode" "${jcodePackage}/bin/jcode";
in {
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [
      scopedWorkload
      astBroWrapper
      sbWrapper
      codexAgentPackage
      codexAcpWrapper
      claudeWrapper
      grokAgentPackage
      scopedJcode
    ];

    home.file = {
      "${agentWrapperDirectory}/codex".source = "${codexAgentPackage}/bin/codex";
      "${agentWrapperDirectory}/codex-acp".source = "${codexAcpWrapper}/bin/codex-acp";
      "${agentWrapperDirectory}/codex-code-mode-host".source = "${codexAgentPackage}/bin/codex-code-mode-host";
      "${agentWrapperDirectory}/claude".source = "${claudeWrapper}/bin/claude";
      "${agentWrapperDirectory}/grok".source = "${grokAgentPackage}/bin/grok";
      "${agentWrapperDirectory}/agent".source = "${grokAgentPackage}/bin/agent";
      "${agentWrapperDirectory}/jcode".source = "${scopedJcode}/bin/jcode";
    };
    home.sessionPath = [agentWrapperDirectory];

    home.activation.configureCodexVscode = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ -f ${lib.escapeShellArg vscodeMachineSettings} ]; then
        ${pkgs.jq}/bin/jq --arg executable ${lib.escapeShellArg "${agentWrapperDirectory}/codex"} \
          '."chatgpt.cliExecutable" = $executable' \
          ${lib.escapeShellArg vscodeMachineSettings} > ${lib.escapeShellArg "${vscodeMachineSettings}.tmp"}
        ${pkgs.coreutils}/bin/mv ${lib.escapeShellArg "${vscodeMachineSettings}.tmp"} ${lib.escapeShellArg vscodeMachineSettings}
      fi
    '';

    # 限制单次 Cargo 的内部并发，避免一个构建再次同时启动数十个重型链接器。
    home.file.".cargo/config.toml".text = ''
      [build]
      jobs = 6
    '';

    home.shellAliases = {
      cargo = "scoped-workload build cargo";
      codex = "scoped-workload codex ${lib.escapeShellArg "${configuredCodex}/bin/codex"}";
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

      "ai-codex" = {
        Unit.Description = "Isolated Codex agent workloads";
      };
      "ai-grok" = {
        Unit.Description = "Isolated Grok agent workloads";
      };
      "ai-claude" = {
        Unit.Description = "Isolated Claude agent workloads";
      };
      "ai-jcode" = {
        Unit.Description = "Isolated Jcode agent workloads";
        Slice = {
          ManagedOOMMemoryPressure = "kill";
          ManagedOOMMemoryPressureDurationSec = "15s";
          ManagedOOMMemoryPressureLimit = "70%";
          ManagedOOMPreference = "none";
          ManagedOOMSwap = "kill";
          MemoryMax = "60%";
          MemorySwapMax = "8G";
        };
      };

      analysis = {
        Unit.Description = "Disposable AST analysis workloads";
        Slice = {
          ManagedOOMMemoryPressure = "kill";
          ManagedOOMMemoryPressureDurationSec = "15s";
          ManagedOOMMemoryPressureLimit = "70%";
          ManagedOOMSwap = "kill";
          MemoryMax = "60%";
          MemorySwapMax = "8G";
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
