{
  config,
  flake,
  lib,
  pkgs,
  ...
}: let
  packages = flake.inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
  homeDirectory = config.home.homeDirectory;
  workspace = "${homeDirectory}/notebooks";
  tokenDirectory = "${config.xdg.stateHome}/omp-jupyter";
  tokenFile = "${tokenDirectory}/token";
  runtime = packages.jupyterlab-mcp;

  jupyterLab = pkgs.writeShellScriptBin "omp-jupyterlab" ''
    set -euo pipefail
    JUPYTER_TOKEN="$(<${lib.escapeShellArg tokenFile})"
    : "''${JUPYTER_TOKEN:?Jupyter 令牌文件为空或不可读}"
    export JUPYTER_TOKEN
    exec ${runtime}/bin/jupyter-lab \
      --no-browser --ip=127.0.0.1 --port=8888 \
      --ServerApp.port_retries=0 \
      --ServerApp.root_dir=${lib.escapeShellArg workspace} \
      --ServerApp.log_level=WARN "$@"
  '';

  jupyterMcp = pkgs.writeShellScriptBin "omp-jupyter-mcp" ''
    set -euo pipefail
    export JUPYTER_URL=http://127.0.0.1:8888
    export ALLOW_IMG_OUTPUT=true
    JUPYTER_TOKEN="$(<${lib.escapeShellArg tokenFile})"
    : "''${JUPYTER_TOKEN:?Jupyter 令牌文件为空或不可读}"
    export JUPYTER_TOKEN
    exec ${packages.jupyter-mcp-server}/bin/jupyter-mcp-server "$@"
  '';
in
  lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.packages = [
      packages.nb-cli
      packages.jupyter-mcp-server
      runtime
      jupyterLab
      jupyterMcp
    ];

    home.file.".agents/skills/notebook-cli".source = "${packages.nb-cli}/share/skills/notebook-cli";
    xdg.dataFile."jupyter/kernels/omp-python/kernel.json".text = builtins.toJSON {
      argv = ["${runtime}/bin/notebook-python" "-m" "ipykernel_launcher" "-f" "{connection_file}"];
      display_name = "Python (OMP Notebook)";
      language = "python";
    };

    # 令牌仅在激活时本地生成，不进入 Nix store；已有令牌保持不变。
    home.activation.ompJupyterSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg tokenDirectory}
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p -m 700 ${lib.escapeShellArg workspace}
      if [ ! -s ${lib.escapeShellArg tokenFile} ]; then
        $DRY_RUN_CMD ${pkgs.python3}/bin/python -c \
          'import os, secrets; fd = os.open(${builtins.toJSON tokenFile}, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600); os.write(fd, secrets.token_urlsafe(32).encode()); os.close(fd)'
      fi
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod 600 ${lib.escapeShellArg tokenFile}
    '';

    systemd.user.startServices = "sd-switch";
    systemd.user.services.omp-jupyterlab = {
      Unit = {
        Description = "OMP 本地 Notebook 与 Kernel 服务";
        After = ["network.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${jupyterLab}/bin/omp-jupyterlab";
        WorkingDirectory = workspace;
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        Environment = ["PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"];
      };
      Install.WantedBy = ["default.target"];
    };
  }
