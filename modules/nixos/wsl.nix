{
  flake,
  pkgs,
  ...
}: {
  imports = [flake.inputs.nixos-wsl.nixosModules.default];

  wsl = {
    enable = true;
    defaultUser = "xmin";
    interop = {
      register = true;
      includePath = false;
    };
    wslConf = {
      interop = {
        enabled = true;
        appendWindowsPath = false;
      };
      network.generateHosts = false;
    };
    # Zed 远程开发依赖 WSL 中这些固定路径。
    extraBin = [
      {src = "${pkgs.coreutils}/bin/uname";}
      {src = "${pkgs.coreutils}/bin/mkdir";}
      {src = "${pkgs.coreutils}/bin/cp";}
    ];
  };

  environment.systemPackages = [pkgs.bashInteractive];

  # Codex 的 WSL 兼容层需要固定的 /usr/bin/bash。
  system.activationScripts.codexWslCompat = {
    deps = ["usrbinenv"];
    text = ''
      mkdir -p /usr/bin
      ln -sfn ${pkgs.bashInteractive}/bin/bash /usr/bin/bash
    '';
  };

  services.cloudflareTunnelDirectRoutes.enable = true;

  # 避免 Windows 动态保留的端口区间。
  services.openssh.ports = [24022];
  system.stateVersion = "25.05";
}
