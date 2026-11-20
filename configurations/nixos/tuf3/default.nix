{
  flake,
  modulesPath,
  pkgs,
  ...
}: let
  magpiePackage = pkgs.callPackage ./magpie.nix {};
  uuRemotePackage = pkgs.callPackage ./uu-remote-linux.nix {releaseMetadata = flake.inputs.uuRemoteLinuxRelease;};
in {
  imports = [
    flake.inputs.self.nixosModules.default
    flake.inputs.self.nixosModules.nix-cache
    flake.inputs.ghelper.nixosModules.default
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

  environment.systemPackages = [
    (pkgs.callPackage ./krunner-pinyin-search.nix {src = flake.inputs.krunnerPinyinSrc;})
  ];
  systemd.packages = [uuRemotePackage];

  services = {
    ghelper.enable = true;
    openssh.enable = false;
    desktopManager.plasma6.enable = true;
    displayManager.sddm = {
      enable = true;
      # 登录界面用 X11，规避 KDE #527428 报告的屏幕输出异常。
      wayland.enable = false;
    };
    xserver.enable = true;
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
    # 补齐 WPS 与 Office 文档常用字体及其度量兼容替代。
    caladea
    carlito
    corefonts
    lxgw-wenkai
    source-han-sans
    zcool-qingke-huangyou
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
      (pkgs.callPackage ./weflow.nix {releaseMetadata = flake.inputs.weflowRelease;})
      uuRemotePackage
      magpiePackage
    ];

    # 阻止 Magpie 生成绕过启动包装的用户级快捷方式。
    xdg.dataFile."applications/magpie.desktop".source = "${magpiePackage}/share/applications/magpie.desktop";

    xdg.configFile."autostart/snipaste.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Snipaste
      Exec=${pkgs.snipaste}/bin/snipaste
      OnlyShowIn=KDE;
    '';
  };
}
