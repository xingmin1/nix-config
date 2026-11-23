{
  config,
  flake,
  lib,
  modulesPath,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  magpiePackage = pkgs.callPackage ./magpie.nix {
    releaseMetadata = flake.inputs.magpieRelease;
    appIcon = flake.inputs.magpieIcon;
  };
  uuRemotePackage = pkgs.callPackage ./uu-remote-linux.nix {releaseMetadata = flake.inputs.uuRemoteLinuxRelease;};
  nextkdeWallpaperShell = pkgs.runCommand "nextkde-wallpaper-shell" {} ''
    src=${flake.inputs.nextkde}/apps/lockscreen
    dest=$out/share/plasma/shells/org.kos.desktop
    install -Dm644 "$src/metadata.json" "$dest/metadata.json"
    install -Dm644 "$src/contents/defaults" "$dest/contents/defaults"
  '';
  herdrVpsAddress = "216.167.127.46";
  herdrVpsSshPort = 2911;
  herdrVpsForwardPort = 2912;
  herdrLocalSshPort = 2222;
  herdrVpsKnownHosts = pkgs.writeText "herdr-vps-known-hosts" ''
    [${herdrVpsAddress}]:${toString herdrVpsSshPort} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICNszTEGtPCmXPR/VSwB7ucZanAHm5X/EuTmBMxp8Am6
  '';
in {
  imports = [
    flake.inputs.self.nixosModules.default
    flake.inputs.self.nixosModules.nix-cache
    flake.inputs.ghelper.nixosModules.default
    flake.inputs.nextkde.nixosModules.kos
    (modulesPath + "/installer/scan/not-detected.nix")
    ./hardware-configuration.nix
    ./micron-code-login.nix
  ];

  networking = {
    hostName = "tuf3";
    networkmanager.enable = true;
    # Sheprd 手机控制只接受当前 Wi-Fi 局域网的 IPv4 连接。
    firewall.extraCommands = ''
      iptables -w -A nixos-fw -i wlp44s0 -s 192.168.5.0/24 -p tcp --dport 7443 -j nixos-fw-accept
    '';
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
  # 本机 s2idle 曾卡在进入睡眠，双屏和独显已实测能从 S3 恢复。
  systemd.sleep.settings.Sleep.MemorySleepMode = "deep";
  # 禁用 RTX 3060 上游端口 PEG1 的唤醒后，本机实测可完整进入 S4 并恢复双屏。
  systemd.services.systemd-hibernate = let
    peg1Wakeup = "/sys/bus/pci/devices/0000:00:01.0/power/wakeup";
  in {
    overrideStrategy = "asDropin";
    serviceConfig = {
      RuntimeDirectory = "tuf3-hibernate";
      ExecStartPre = pkgs.writeShellScript "tuf3-hibernate-disable-peg1-wakeup" ''
        set -eu
        wakeup=${peg1Wakeup}
        if [[ -e "$wakeup" && $(<"$wakeup") == enabled ]]; then
          : > "$RUNTIME_DIRECTORY/restore-peg1-wakeup"
          printf '%s\n' disabled > "$wakeup"
          echo 'PEG1 wakeup disabled for hibernation.'
        fi
      '';
      ExecStopPost = pkgs.writeShellScript "tuf3-hibernate-restore-peg1-wakeup" ''
        set -eu
        if [[ -e "$RUNTIME_DIRECTORY/restore-peg1-wakeup" ]]; then
          printf '%s\n' enabled > ${peg1Wakeup}
          echo 'PEG1 wakeup restored after hibernation.'
        fi
      '';
    };
  };
  # zram 继续优先服务日常换页。磁盘休眠由 systemd 通过 EFI 记录恢复位置。
  swapDevices = [
    {
      device = "/hibernate.swap";
      size = 48 * 1024;
      priority = 1;
    }
  ];
  system.stateVersion = "26.05";

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages =
    [
      (pkgs.callPackage ./krunner-pinyin-search.nix {src = flake.inputs.krunnerPinyinSrc;})
      # 手机通过非交互 SSH 会话调用 herdr-core。
      flake.inputs.llm-agents.packages.${system}.herdr-core
    ]
    ++ lib.optionals config.services.kos.enable [
      nextkdeWallpaperShell
      # NextKDE 的平台服务使用它们记录 Wayland 剪贴板历史。
      pkgs.wl-clipboard
      pkgs.cliphist
      # NextKDE 台前侧栏调用 qdbus6，Nixpkgs 的 Qt 6 工具安装为 qdbus。
      (pkgs.writeShellScriptBin "qdbus6" ''
        exec ${lib.getExe' pkgs.kdePackages.qttools "qdbus"} "$@"
      '')
    ];
  # 上游 NixOS 模块启动了 KOS，但遗漏了只绘制壁纸的 Plasma 桌面包。
  # 使用系统默认值，停用 KOS 后可回到独立保存的原 Plasma 布局。
  environment.etc."xdg/plasmashellrc" = lib.mkIf config.services.kos.enable {
    text = ''
      [Shell]
      ShellPackage=org.kos.desktop
    '';
  };
  systemd.packages = [uuRemotePackage];
  systemd.tmpfiles.rules = [
    # Magpie Cursor Bridge 只探测固定安装目录，使用用户配置的稳定路径跟随 Nix 构建。
    "L /opt/cursor - - - - /etc/profiles/per-user/xmin/lib/cursor"
  ];

  # Cursor 3.30 的扩展进程（cursor-always-local / cursor-agent-host）通过
  # @vscode/proxy-agent 只读取 /etc/ssl/certs/ca-certificates.crt，忽略 ~/.pki/nssdb、
  # argv.json 与 NODE_EXTRA_CA_CERTS；加入此处同步更新 ca-certificates.crt 与
  # p11-kit trust-source（供 Chromium NSS 使用）。仅含本机桥接的公钥证书。
  # 来源：~/.config/magpie-cursor-bridge/data/ca/ca.crt
  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
      MIIEPTCCAqWgAwIBAgIUAd6H68dAOQZWn2NWWlcFiCc7vFswDQYJKoZIhvcNAQEL
      BQAwNTEdMBsGA1UEAwwUQ3Vyc29yIEJZT0sgTG9jYWwgQ0ExFDASBgNVBAoMC0N1
      cnNvciBCWU9LMB4XDTI2MTEyMTAyMDU1MloXDTM2MTEyMDAyMTA1MlowNTEdMBsG
      A1UEAwwUQ3Vyc29yIEJZT0sgTG9jYWwgQ0ExFDASBgNVBAoMC0N1cnNvciBCWU9L
      MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAr3aixuLMOkNv6ZLjXy7L
      1uH3k+6/STG5ZwoWu3LA6o246njKNWdoMO0cI8qFmsM48phUuI09fuFBT/lN1+pF
      u9WrRz4qWEAEedAfU26544ZZaMcKAjDBQHaU/KVVAjmIXYQPx7MBGb/KcqQlVW5Q
      okeHzakRNgqxtME48gkENAb+94e1OC/t7OqENkJiEhp95VmFb+gpE7cohtnBdqSB
      8pnd/5V5KeFvK1MILD4Vd1tRJmu0fzOyYpOjVOCglJtdEWyzXtNOZKYEHXBUs6TJ
      lNjk0DKwzILzj2gfm4I+M7Dxs5TGAyuH26rTyb+2fUzwaYwW9h4ADpZ6DmFOps+b
      SyOBENNBNqDYO4eS+4qtVpWMIMSrQ0zJxph7Ppgyr9eLJqGZRY5YZ392iRo3ZOVJ
      PXT75LAM9kqatdlgAo4YJXLaqZhoqg2A0gOFcYSnqB5o77w/2Mboicf4bOsLm9GL
      QuHK7YaKCXoHngW5Fz22sTOEsuJ2V1HDBFIKDtH3gtKDAgMBAAGjRTBDMA4GA1Ud
      DwEB/wQEAwIBhjAdBgNVHQ4EFgQUlzEH+/U3YDIbTWWAWOE1t3hGwI8wEgYDVR0T
      AQH/BAgwBgEB/wIBADANBgkqhkiG9w0BAQsFAAOCAYEAIZGL19jx1PrAVafV5VOU
      9r3kj9k7iObkZ25EgfXW0AyTwpM9F3P2KlDUDRLh8YJ1MlxKqJzspnSVI7e+8LJk
      NccJnia9GsXbqMIyW6kZaC19KB9pG65JjZaaeJEk+dI+573/WjUy/C3V29yyBvFf
      YGiA5UWZ1hOQ/ZWQZ2TN2LvG7Ia+tr++uhXtoKjtRt+hAaPxTq38Q5nSCtQpRFHK
      TXteTh0x1xurqIKhaQjNic0TNwZz+HnZR9Bl5ZC56J/YkUjvBklWgxP3/GgW0Du4
      EtNbhT1nT/gBb7hS5ad3YawJUOpCiOFtWZb5OS0VRgbwF84OcZRiC7sq82ZcaFLc
      Um1Bk4PB2t3n5rhJ4+Pz9oSZHudRzTaX6vY0oVuLnxhSLT9VMV4HxbMvESartfMZ
      AK6KPPsrBqgxU91M7XHO6/Gwc3kbGlh+5RFqGBjphooaovCIAxkRZSP01ZKsrDoi
      FRPMQzRCt5eWt2s0Cl51F6BllOU/5OTavDO35eqzRSJ/
      -----END CERTIFICATE-----
    ''
  ];

  services = {
    ghelper.enable = true;
    openssh = {
      enable = true;
      openFirewall = false;
      # 手机经 VPS 转发接入，笔记本的 SSH 只监听本机。
      listenAddresses = [
        {
          addr = "127.0.0.1";
          port = herdrLocalSshPort;
        }
      ];
      authorizedKeysInHomedir = false;
      authorizedKeysFiles = ["%h/.ssh/authorized_keys_herdr"];
      settings = {
        AllowUsers = ["xmin"];
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AllowAgentForwarding = false;
        AllowTcpForwarding = false;
      };
    };
    desktopManager.plasma6.enable = true;
    kos.enable = true;
    displayManager.sddm = {
      enable = true;
      # Xorg 在本机混合显卡上无法创建登录界面的 pixmap。
      wayland.enable = true;
    };
    xserver.enable = true;
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
    };
  };
  security.rtkit.enable = true;

  systemd.services.herdr-vps-tunnel = {
    description = "Herdr mobile SSH reverse tunnel";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target" "sshd.service"];
    requires = ["sshd.service"];
    serviceConfig = {
      User = "xmin";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.openssh}/bin/ssh"
        "-F /dev/null -N -T"
        "-o BatchMode=yes -o IdentitiesOnly=yes -o IdentityAgent=none"
        "-o StrictHostKeyChecking=yes -o UpdateHostKeys=no"
        "-o UserKnownHostsFile=${herdrVpsKnownHosts}"
        "-o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3"
        "-i /home/xmin/.ssh/herdr-vps-ed25519"
        "-p ${toString herdrVpsSshPort}"
        "-R 0.0.0.0:${toString herdrVpsForwardPort}:127.0.0.1:${toString herdrLocalSshPort}"
        "herdr-tunnel@${herdrVpsAddress}"
      ];
      Restart = "always";
      RestartSec = "15s";
    };
    unitConfig.StartLimitIntervalSec = 0;
  };

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

  home-manager.users.xmin = let
    intelDesktop = {
      text = ''
        [Service]
        UnsetEnvironment=__NV_PRIME_RENDER_OFFLOAD __GLX_VENDOR_LIBRARY_NAME
      '';
    };
    dockWidgetPath = "shell/desktop/modules/dock/DockTemperatureWidget.qml";
    dockUsageWidget = pkgs.runCommand "nextkde-dock-usage.qml" {nativeBuildInputs = [pkgs.patch];} ''
      install -Dm644 ${flake.inputs.nextkde}/${dockWidgetPath} ${dockWidgetPath}
      patch -p1 < ${./nextkde-dock-usage.patch}
      cp ${dockWidgetPath} "$out"
    '';
    installDockUsageWidget = pkgs.writeShellScript "install-nextkde-dock-usage" ''
      ${pkgs.coreutils}/bin/install -m644 ${dockUsageWidget} \
        "$HOME/.config/quickshell/kos/desktop/modules/dock/DockTemperatureWidget.qml"
    '';
    sampleDockVram = pkgs.writeShellScript "nextkde-dock-vram" ''
      set -euo pipefail
      sample="$RUNTIME_DIRECTORY/percent"
      while true; do
        percent=$(
          ${pkgs.coreutils}/bin/timeout 4 /run/current-system/sw/bin/nvidia-smi \
            --id=00000000:01:00.0 --query-gpu=memory.used,memory.total \
            --format=csv,noheader,nounits 2>/dev/null |
            ${pkgs.gawk}/bin/awk -F, '
              NF == 2 && $1 ~ /^[[:space:]]*[0-9]+[[:space:]]*$/ &&
              $2 ~ /^[[:space:]]*[0-9]+[[:space:]]*$/ && $2 > 0 && $1 <= $2 {
                printf "%d\n", ($1 * 100 / $2) + 0.5
              }'
        ) || percent=
        printf '%s\n' "''${percent:--1}" > "$sample.next"
        ${pkgs.coreutils}/bin/mv -f "$sample.next" "$sample"
        ${pkgs.coreutils}/bin/sleep 5
      done
    '';
  in {
    # Bitwarden 使用内核 keyring，避免 secretmem 阻止磁盘休眠。
    systemd.user.sessionVariables.SECURE_KEY_CONTAINER_BACKEND = "keyctl";

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
      flake.inputs.llm-agents.packages.${system}.herdr-app
      (callPackage ./sheprd.nix {releaseChecksums = flake.inputs.sheprdChecksums;})
      flake.inputs.antigravity-nix.packages.${system}.default
      (callPackage ./cursor.nix {})
      (callPackage ./cursor-cli.nix {})
      cf
      (symlinkJoin {
        name = "wemeet-desktop";
        paths = [wemeet];
        postBuild = ''
          # 腾讯会议原生 Wayland 窗口在拖动共享横条时会触发尺寸协议错误。
          # 使用 Nixpkgs 的 XWayland 入口及其屏幕采集兼容库。
          ln -sfn ${writeShellScript "wemeet-launch" ''
            if [ "''${XDG_SESSION_TYPE:-}" = wayland ]; then
              exec ${wemeet}/bin/wemeet-xwayland "$@"
            fi
            exec ${wemeet}/bin/wemeet "$@"
          ''} "$out/bin/wemeet"
        '';
      })
      (symlinkJoin {
        name = "typora-wayland-scale";
        paths = [typora];
        nativeBuildInputs = [makeWrapper];
        postBuild = ''
          # Electron 在 Wayland 上把额外的 UI 倍率乘到 KDE 的输出倍率上。
          # 将额外倍率设为 1，避免在混合缩放的屏幕之间重复放大。
          wrapProgram "$out/bin/typora" \
            --run 'if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
              set -- --force-device-scale-factor=1 "$@"
            fi'
        '';
      })
      (pkgs.callPackage ./arcmd.nix {releaseChecksums = flake.inputs.arcmdChecksums;})
      (pkgs.callPackage ./weflow.nix {src = flake.inputs.weflowSrc;})
      uuRemotePackage
      magpiePackage
      # Magpie Cursor Bridge 需要 certutil 导入用户 NSS 证书库，以及 sqlite3 做数据库检查与清理。
      nssTools
      sqlite
    ];

    # 让 Magpie Cursor Bridge 维护的 cursor-agent-bridge 包装器进入默认 PATH。
    home.sessionPath = ["/home/xmin/.config/magpie-cursor-bridge/bin"];

    # Plasma 应用统一优先使用独显。Vulkan 仍可选择其他显卡。
    xdg.configFile."plasma-workspace/env/nvidia-offload.sh".text = ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
    '';

    # KWin 与任务栏使用同一块核显，避免缩略图在两块显卡之间传递。
    xdg.configFile."systemd/user/plasma-kwin_wayland.service.d/prime-offload.conf" = intelDesktop;
    xdg.configFile."systemd/user/plasma-plasmashell.service.d/prime-offload.conf" = intelDesktop;
    # 共享选择器在核显上显示 KWin 的屏幕和窗口预览。
    xdg.configFile."systemd/user/plasma-xdg-desktop-portal-kde.service.d/prime-offload.conf" = intelDesktop;
    # 保持 RTX 3060 渲染，用 Vulkan 避开 Qt OpenGL 路径的着色器编译错误。
    xdg.configFile."systemd/user/kos-shell.service.d/nextkde-local.conf".text = ''
      [Unit]
      Wants=kos-dock-vram.service
      After=kos-dock-vram.service

      [Service]
      Environment=QSG_RHI_BACKEND=vulkan
      Environment=VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json
      ExecStartPre=${installDockUsageWidget}
    '';

    xdg.configFile."systemd/user/kos-dock-vram.service".text = ''
      [Unit]
      Description=NextKDE Dock RTX 3060 VRAM readings
      PartOf=kos-shell.service

      [Service]
      RuntimeDirectory=kos-dock-vram
      Environment=LC_ALL=C
      ExecStart=${sampleDockVram}
    '';

    # 阻止 Magpie 生成绕过启动包装的用户级快捷方式。
    xdg.dataFile."applications/magpie.desktop".source = "${magpiePackage}/share/applications/magpie.desktop";

    # KDE 登录后再启动主机服务，确保 Wayland 会话已就绪。
    xdg.configFile."systemd/user/xdg-desktop-autostart.target.wants/uuremote-native.service".source = "${uuRemotePackage}/share/systemd/user/uuremote-native.service";

    # 使用带渲染环境的包装入口，登录时只打开托盘。
    xdg.configFile."autostart/magpie.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Magpie
      Exec=${magpiePackage}/bin/magpie tray
      Icon=magpie
      Terminal=false
    '';

    xdg.configFile."autostart/snipaste.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Snipaste
      Exec=${pkgs.snipaste}/bin/snipaste
      OnlyShowIn=KDE;
    '';
  };
}
