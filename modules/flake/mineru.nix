{...}: {
  perSystem = {pkgs, ...}: let
    inherit (pkgs) lib;
    mineruCommands = [
      "mineru"
      "mineru-api"
      "mineru-kit"
      "mineru-models-download"
      "mineru-openai-server"
      "mineru-router"
      "mineru-webui"
    ];
  in {
    packages.mineru = pkgs.symlinkJoin {
      name = "mineru";
      paths = map (bin:
        pkgs.writeShellScriptBin bin ''
          exec ${pkgs.uv}/bin/uv tool run --from "mineru>=4.0,<5" ${bin} "$@"
        '')
      mineruCommands;

      meta = {
        description = "MinerU — 适用于智能体的高精度多模态文档解析与提取工具";
        homepage = "https://github.com/opendatalab/MinerU";
        license = lib.licenses.mit;
        mainProgram = "mineru";
        platforms = lib.platforms.unix;
      };
    };
  };
}
