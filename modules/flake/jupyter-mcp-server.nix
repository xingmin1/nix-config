{...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib;
    # MCP、Lab 和内核共用 uv 隔离环境；仅使用发布的 wheels，不编译源码。
    runtimeArgs = lib.escapeShellArgs [
      "--no-config"
      "tool"
      "run"
      "--no-build"
      "--no-python-downloads"
      "--python"
      "${pkgs.python312}/bin/python3"
      "--from"
      "jupyter-mcp-server==2.2.4"
      "--with"
      "jupyterlab==4.6.4"
      "--with"
      "jupyter-collaboration==5.0.4"
      "--with"
      "jupyter-mcp-tools==0.1.8"
      "--with"
      "ipykernel==7.4.0"
      "--with"
      "code-sandboxes==1.10.0"
      "--with"
      "mcp==2.3.0"
      "--with"
      "jupytext==1.19.6"
    ];
    command = name: executable:
      pkgs.writeShellScriptBin name ''
        # PyPI 的本机 wheels 需要 Nix 提供的 C++ 运行库；保留调用方环境。
        export LD_LIBRARY_PATH="${lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        exec ${pkgs.uv}/bin/uv ${runtimeArgs} ${executable} "$@"
      '';
  in {
    packages = {
      jupyter-mcp-server = (command "jupyter-mcp-server" "jupyter-mcp-server --transport stdio").overrideAttrs (_: {
        meta = {
          description = "固定发布版 Jupyter MCP stdio 服务（独立 Python 环境）";
          homepage = "https://github.com/datalayer/jupyter-mcp-server";
          license = lib.licenses.bsd3;
          mainProgram = "jupyter-mcp-server";
          platforms = lib.platforms.linux;
        };
      });
      jupyterlab-mcp = pkgs.symlinkJoin {
        name = "jupyterlab-mcp";
        paths = [
          (command "jupyter" "jupyter")
          (command "jupyter-lab" "jupyter-lab")
          (command "jupytext" "jupytext")
          # 明确入口，避免覆盖用户全局 python/python3。
          (command "notebook-python" "python")
        ];
        meta = {
          description = "JupyterLab、协作扩展及与 MCP 共用的 Python 内核环境";
          homepage = "https://jupyter.org";
          license = lib.licenses.bsd3;
          mainProgram = "jupyter-lab";
          platforms = lib.platforms.linux;
        };
      };
    };
  };
}
