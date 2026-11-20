{
  flake,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [
    flake.inputs.self.nixosModules.default
    flake.inputs.self.nixosModules.nix-cache
    (modulesPath + "/installer/scan/not-detected.nix")
    ./hardware-configuration.nix
    ./micron-code-login.nix
  ];

  networking = {
    hostName = "tuf3";
    networkmanager.enable = true;
  };

  boot.loader = {
    efi = {
      efiSysMountPoint = "/boot/efi";
      canTouchEfiVariables = false;
    };
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = false;
      device = "nodev";
      configurationLimit = 10;
    };
  };

  # Windows 默认将硬件时钟当作本地时间。
  time.hardwareClockInLocalTime = true;
  zramSwap.enable = true;
  system.stateVersion = "26.05";

  nixpkgs.config.allowUnfree = true;

  services = {
    openssh.enable = false;
    desktopManager.plasma6.enable = true;
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
    };
  };
  security.rtkit.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [
        pkgs.fcitx5-gtk
        flake.inputs.wetypex.packages.${pkgs.stdenv.hostPlatform.system}.fcitx5-wetypex
        (pkgs.fcitx5-rime.override {rimeDataPkgs = [pkgs.rime-ice];})
      ];
    };
  };
  fonts.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
  ];

  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
    autoStart = true;
    group = "wheel";
  };

  users.users.xmin = {
    uid = 1000;
    group = "users";
    extraGroups = ["wheel" "networkmanager"];
  };

  home-manager.users.xmin = {
    # 这些后台服务依赖 WSL 现有的本地配置或账号授权。
    services = {
      ccConnect.enable = false;
      cloudflaredTunnel.enable = false;
      codex2api.enable = false;
      grokOpenAICompat.enable = false;
    };
    home.packages = with pkgs; [
      google-chrome
      bitwarden-desktop
      wechat
      qq
      snipaste
      wpsoffice-cn
      feishu
      (symlinkJoin {
        name = "chatgpt-wayland-ime";
        paths = [chatgpt];
        nativeBuildInputs = [makeWrapper];
        postBuild = ''
          # KDE Wayland 下使用原生输入法协议，避免 XIM 快速输入时漏键。
          wrapProgram "$out/bin/chatgpt" \
            --run 'if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
              set -- --ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3 "$@"
            fi'
        '';
      })
      zed-editor
      vscode
      code-cursor
      wemeet
      typora
      (pkgs.callPackage ./arcmd.nix {releaseChecksums = flake.inputs.arcmdChecksums;})
      (pkgs.callPackage ./magpie.nix {})
    ];

    xdg.configFile."autostart/snipaste.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Snipaste
      Exec=${pkgs.snipaste}/bin/snipaste
      OnlyShowIn=KDE;
    '';
  };
}
