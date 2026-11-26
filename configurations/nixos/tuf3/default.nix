{
  flake,
  lib,
  modulesPath,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  tailscaleRelease = pkgs.stdenvNoCC.mkDerivation {
    pname = "tailscale";
    version = "1.104.7";
    src = pkgs.fetchurl {
      url = "https://pkgs.tailscale.com/stable/tailscale_1.104.7_amd64.tgz";
      hash = "sha256-5WaT/3SmTyWRt+gZwoBjWhAKrh3fsO8Fj80FK3zY0Ww=";
    };
    sourceRoot = "tailscale_1.104.7_amd64";
    dontBuild = true;
    installPhase = ''
      install -Dm755 tailscale "$out/bin/tailscale"
      install -Dm755 tailscaled "$out/bin/tailscaled"
      install -d "$out/lib/systemd/system"
      sed \
        -e "/EnvironmentFile=\\/etc\\/default\\/tailscaled/d" \
        -e "s#/usr/sbin/tailscaled#$out/bin/tailscaled#g" \
        systemd/tailscaled.service > "$out/lib/systemd/system/tailscaled.service"
      install -Dm644 systemd/tailscaled.defaults "$out/lib/systemd/system/tailscaled.defaults"
      install -Dm644 systemd/tailscale-online.target "$out/lib/systemd/system/tailscale-online.target"
      install -Dm644 systemd/tailscale-wait-online.service "$out/lib/systemd/system/tailscale-wait-online.service"
    '';
  };
  tailscaleControlProxy = pkgs.writeText "tailscale-control-proxy.py" ''
    import asyncio, re, socket, ssl

    LISTEN = ("127.0.0.1", 8443)
    SNI = "login.tailscale.com"
    context = ssl.create_default_context()

    async def pipe(reader, writer):
        try:
            while data := await reader.read(65536):
                writer.write(data)
                await writer.drain()
        except Exception:
            pass
        finally:
            writer.close()

    async def handle(client_reader, client_writer):
        try:
            first = await asyncio.wait_for(client_reader.read(65536), 30)
            if not first:
                client_writer.close()
                return
            header, separator, rest = first.partition(b"\\r\\n\\r\\n")
            header = re.sub(
                rb"(?im)^host:.*$",
                b"Host: " + SNI.encode(),
                header,
                count=1,
            )
            address = socket.gethostbyname(SNI)
            remote_reader, remote_writer = await asyncio.open_connection(
                address, 443, ssl=context, server_hostname=SNI
            )
            remote_writer.write(header + separator + rest)
            await remote_writer.drain()
            await asyncio.gather(
                pipe(client_reader, remote_writer),
                pipe(remote_reader, client_writer),
            )
        except Exception:
            client_writer.close()

    async def main():
        server = await asyncio.start_server(handle, *LISTEN)
        async with server:
            await server.serve_forever()

    asyncio.run(main())
  '';
  magpiePackage = pkgs.callPackage ./magpie.nix {
    releaseMetadata = flake.inputs.magpieRelease;
    appIcon = flake.inputs.magpieIcon;
  };
  uuRemotePackage = pkgs.callPackage ./uu-remote-linux.nix {releaseMetadata = flake.inputs.uuRemoteLinuxRelease;};
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
    (modulesPath + "/installer/scan/not-detected.nix")
    ./hardware-configuration.nix
    ./micron-code-login.nix
    ./phone-input.nix
  ];

  networking = {
    hostName = "tuf3";
    networkmanager.enable = true;
    # Sheprd 手机控制只接受当前 Wi-Fi 局域网的 IPv4 连接。
    firewall.extraCommands = ''
      iptables -w -A nixos-fw -i wlp44s0 -s 192.168.5.0/24 -p tcp --dport 7443 -j nixos-fw-accept
      iptables -w -A nixos-fw -i wlp44s0 -s 192.168.5.0/24 -p tcp --dport 6768 -j nixos-fw-accept
    '';
  };

  # Agent Tincan 通过 Tailscale 私有网络连接本机与其他 Agent。
  services.tailscale = {
    enable = true;
    package = tailscaleRelease;
  };

  # 该网络会拦截 tailscale.com 的原始 SNI，转发器保持控制面连接可用。
  systemd.services.tailscale-control-proxy = {
    description = "Tailscale control-plane SNI relay";
    wantedBy = ["multi-user.target"];
    before = ["tailscaled.service"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${tailscaleControlProxy}";
      Restart = "always";
      RestartSec = 2;
      DynamicUser = true;
    };
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
  # Alder Lake i915 在恢复后出现 QSGRenderThread GPU HANG 和黑屏，先按社区常用方案关闭 PSR 与显示电源 C-state。
  # 详见 docs/tuf3-power-sleep-research-2026-11-25.md，验证稳定后再评估是否恢复省电路径。
  boot.kernelParams = [
    "i915.enable_psr=0"
    "i915.enable_dc=0"
  ];
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

  environment.systemPackages = [
    (pkgs.callPackage ./krunner-pinyin-search.nix {src = flake.inputs.krunnerPinyinSrc;})
    # 手机通过非交互 SSH 会话调用 herdr-core。
    flake.inputs.llm-agents.packages.${system}.herdr-core
  ];
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
      settings = {
        globalOptions.Behavior.ActiveByDefault = true;
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            DefaultIM = "wetypex";
          };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "wetypex";
          GroupOrder."0" = "Default";
        };
      };
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
  programs.localsend.enable = true;

  users.users.xmin = {
    uid = 1000;
    group = "users";
    extraGroups = ["wheel" "networkmanager"];
  };

  home-manager.users.xmin = {
    config,
    lib,
    ...
  }: let
    favnyrKdeOpenWith = pkgs.stdenv.mkDerivation {
      name = "favnyr-kde-open-with";
      src = pkgs.linkFarm "favnyr-kde-open-with-source" [
        {
          name = "CMakeLists.txt";
          path = pkgs.writeText "CMakeLists.txt" ''
            cmake_minimum_required(VERSION 3.16)
            project(favnyr-kde-open-with LANGUAGES CXX)
            find_package(Qt6 REQUIRED COMPONENTS Widgets)
            find_package(KF6KIO REQUIRED)
            add_executable(favnyr-kde-open-with main.cpp)
            target_link_libraries(favnyr-kde-open-with PRIVATE Qt6::Widgets KF6::KIOWidgets)
            install(TARGETS favnyr-kde-open-with DESTINATION bin)
          '';
        }
        {
          name = "main.cpp";
          path = pkgs.writeText "main.cpp" ''
            #include <QApplication>
            #include <QUrl>
            #include <KIO/ApplicationLauncherJob>
            #include <KIO/JobUiDelegateFactory>

            int main(int argc, char **argv)
            {
                QApplication app(argc, argv);
                if (app.arguments().size() < 2) {
                    return 1;
                }
                app.setQuitOnLastWindowClosed(false);

                QList<QUrl> urls;
                for (const auto &path : app.arguments().mid(1)) {
                    urls.append(QUrl::fromLocalFile(path));
                }

                auto *job = new KIO::ApplicationLauncherJob(&app);
                job->setUrls(urls);
                job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
                QObject::connect(job, &KJob::result, &app, [&app](KJob *result) {
                    app.exit(result->error() != 0);
                });
                QMetaObject::invokeMethod(job, &KIO::ApplicationLauncherJob::start, Qt::QueuedConnection);
                return app.exec();
            }
          '';
        }
      ];
      nativeBuildInputs = [pkgs.cmake pkgs.kdePackages.wrapQtAppsHook];
      buildInputs = with pkgs.kdePackages; [qtbase qtwayland kio];
    };
    favnyrArchiveOpeners = (pkgs.formats.toml {}).generate "favnyr-openers.toml" {
      openers = let
        archiveExtensions = ["7z" "ar" "bz2" "cab" "gz" "iso" "lz" "lzma" "lzo" "rar" "tar" "tbz2" "tgz" "txz" "xz" "zip" "zst"];
        archiveOpener = {
          program = "7zz";
          icon = "seven-zip";
          ctx_menu = 1;
          ctx_exts = archiveExtensions;
        };
      in [
        (archiveOpener
          // {
            id = "compress-to-7zip";
            label = "压缩到…";
            args = ["a" "{dir}/{setname}.zip" "{files}"];
            archive_dialog = true;
            ctx_menu = 3;
            ctx_exts = ["*"];
          })
        (archiveOpener
          // {
            id = "extract-here-7zip";
            label = "解压到此处";
            args = ["x" "-o{dir}" "{file}"];
          })
        (archiveOpener
          // {
            id = "extract-to-folder-7zip";
            label = "解压到文件夹";
            args = ["x" "-o{dir}/{stem}" "{file}"];
          })
        {
          # Favnyr 的内置列表会把 .md 当成 text/plain，跳过实际的 Markdown 处理程序。
          id = "kde-open-with";
          label = "用 KDE 选择应用…";
          program = "favnyr-kde-open-with";
          args = ["{files}"];
          ctx_menu = 1;
          ctx_exts = ["*"];
        }
      ];
    };
    seedFavnyrArchiveOpeners = pkgs.writeShellScript "seed-favnyr-archive-openers" ''
      exec ${pkgs.python3.withPackages (ps: [ps.tomlkit])}/bin/python3 - ${favnyrArchiveOpeners} "$1" <<'PY'
      import os
      import sys
      import tomllib
      from pathlib import Path
      from tempfile import NamedTemporaryFile

      import tomlkit
      from tomlkit.items import Array


      def recipe_key(entry):
          if Path(entry.get("program", "")).name in {"7zz", "7z", "7za"}:
              return (tuple(entry.get("args", [])), bool(entry.get("archive_dialog", False)))
          return None


      defaults_path, target = map(Path, sys.argv[1:])
      defaults = tomlkit.parse(defaults_path.read_text())["openers"]
      original = target.read_text() if target.exists() else None
      store = tomlkit.parse(original) if original is not None else tomlkit.document()
      entries = store.setdefault("openers", tomlkit.aot())
      ids = {entry.get("id") for entry in entries}
      recipes = {recipe_key(entry) for entry in entries} - {None}
      missing = [entry for entry in defaults if entry["id"] not in ids and recipe_key(entry) not in recipes]
      if not missing:
          sys.exit(0)

      if isinstance(entries, Array):
          for entry in missing:
              inline = tomlkit.inline_table()
              inline.update(entry.unwrap())
              entries.append(inline)
      else:
          entries.extend(missing)
      updated = tomlkit.dumps(store)
      tomllib.loads(updated)
      target.parent.mkdir(parents=True, exist_ok=True)
      with NamedTemporaryFile(mode="w", dir=target.parent, delete=False) as output:
          output.write(updated)
          pending = Path(output.name)
      try:
          if (target.read_text() if target.exists() else None) != original:
              sys.exit(f"Favnyr changed {target} during activation. Retry after saving.")
          os.replace(pending, target)
      finally:
          pending.unlink(missing_ok=True)
      PY
    '';
    fcitx5Watchdog = pkgs.writeShellScript "fcitx5-watchdog" ''
      set -u

      service="app-org.fcitx.Fcitx5@autostart.service"
      logDir="''${XDG_STATE_HOME:-$HOME/.local/state}"
      logFile="$logDir/fcitx5-watchdog.log"
      cooldownFile="$logDir/fcitx5-watchdog.last-restart"
      mkdir -p "$logDir"

      state=$(${pkgs.coreutils}/bin/timeout 3s ${pkgs.fcitx5}/bin/fcitx5-remote 2>/dev/null || printf 'error')
      backend_count=$(${pkgs.procps}/bin/pgrep -fc '[f]citx5-wetypex-backend' || true)
      service_state=$(${pkgs.systemd}/bin/systemctl --user is-active "$service" 2>/dev/null || true)
      dbus_ready=0
      if ${pkgs.systemd}/bin/busctl --user list 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^org.fcitx.Fcitx5 '; then
        dbus_ready=1
      fi

      if [ "$state" = 2 ] && [ "$backend_count" -gt 0 ] && [ "$dbus_ready" -eq 1 ]; then
        exit 0
      fi

      now=$(${pkgs.coreutils}/bin/date +%s)
      last=0
      if [ -r "$cooldownFile" ]; then
        last=$(cat "$cooldownFile" 2>/dev/null || printf '0')
      fi
      {
        printf '[%s] unhealthy service=%s state=%s wetypex_backend=%s\n' \
          "$(${pkgs.coreutils}/bin/date --iso-8601=seconds)" "$service_state" "$state" "$backend_count"
        ${pkgs.systemd}/bin/systemctl --user --no-pager --full status "$service" 2>&1 | ${pkgs.coreutils}/bin/head -n 18
      } >> "$logFile"

      if [ "$((now - last))" -lt 30 ]; then
        exit 0
      fi
      printf '%s\n' "$now" > "$cooldownFile"

      # KWin 的虚拟键盘可能直接托管 Fcitx，导致生成的 autostart 单元显示
      # inactive。只要 D-Bus 仍有 Fcitx 服务，就先激活输入法，不重启 KWin 托管的进程。
      if [ "$dbus_ready" -eq 1 ] && [ "$state" != 2 ]; then
        ${pkgs.fcitx5}/bin/fcitx5-remote -o 2>/dev/null || true
        sleep 1
        state=$(${pkgs.coreutils}/bin/timeout 3s ${pkgs.fcitx5}/bin/fcitx5-remote 2>/dev/null || printf 'error')
      fi

      if [ "$dbus_ready" -eq 0 ] && { [ "$state" != 2 ] || [ "$backend_count" -eq 0 ]; }; then
        ${pkgs.systemd}/bin/systemctl --user restart "$service"
      fi

      if [ -f "$logFile" ]; then
        ${pkgs.coreutils}/bin/tail -n 400 "$logFile" > "$logFile.tmp"
        ${pkgs.coreutils}/bin/mv "$logFile.tmp" "$logFile"
      fi
    '';
    intelDesktop = {
      text = ''
        [Service]
        UnsetEnvironment=__NV_PRIME_RENDER_OFFLOAD __GLX_VENDOR_LIBRARY_NAME
      '';
    };
  in {
    programs.vicinae = {
      enable = true;
      systemd.enable = true;
      mutableSettings = true;
      settings.providers.applications.entrypoints = lib.mapAttrs (_: alias: {inherit alias;}) {
        "com.toolstack.Folio" = "便笺 笔记 便签 bian jian bi ji bian qian";
        wechat = "wei xin";
        bytedance-feishu = "fei shu";
        wemeetapp = "teng xun hui yi";
        wps-office-et = "biao ge";
        wps-office-wpp = "yan shi";
        wps-office-wps = "wen zi";
        uu-remote-linux = "uu yuan cheng zhu ji";
        uu-remote-linux-viewer = "uu yuan cheng kong zhi duan";
        cups = "da yin ji guan li";
        fcitx5-wetypex-settings = "wetypex she zhi";
        kbd-layout-viewer5 = "jian pan bu ju";
        nvidia-settings = "nvidia she zhi";
        "org.fcitx.fcitx5-migrator" = "shu ru fa qian yi";
        "org.kde.akonadiconsole" = "akonadi kong zhi tai";
        "org.kde.akonadiimportwizard" = "you jian dao ru";
        "org.kde.ark" = "ya suo";
        "org.kde.discover" = "ruan jian zhong xin";
        "org.kde.dolphin" = "wen jian guan li qi";
        "org.kde.drkonqi.coredump.gui" = "beng kui jin cheng";
        "org.kde.elisa" = "yin yue bo fang qi";
        "org.kde.gwenview" = "tu xiang cha kan qi";
        "org.kde.kate" = "bian ji qi";
        "org.kde.khelpcenter" = "bang zhu zhong xin";
        "org.kde.kinfocenter" = "xi tong xin xi";
        "org.kde.kmenuedit" = "cai dan bian ji qi";
        "org.kde.konsole" = "zhong duan";
        "org.kde.kwalletmanager" = "mi ma ku";
        "org.kde.kwrite" = "ji shi ben";
        "org.kde.merkuro.calendar" = "ri li";
        "org.kde.merkuro.contact" = "lian xi ren";
        "org.kde.merkuro.mail" = "you jian";
        "org.kde.okular" = "wen dang cha kan qi";
        "org.kde.plasma-systemmonitor" = "xi tong jian shi qi";
        "org.kde.plasma.emojier" = "biao qing fu hao";
        "org.kde.spectacle" = "jie tu";
        aionui = "aion ui ai agent";
        systemsettings = "xi tong she zhi";
      };
      settings.providers.kde-settings.entrypoints.kcm_fcitx5.alias = "shu ru fa pei zhi";
    };

    # KDE 应用菜单直接打开已运行的启动器。
    xdg.desktopEntries.vicinae = {
      name = "Vicinae";
      comment = "应用启动器";
      exec = "${lib.getExe pkgs.vicinae} open";
      icon = "vicinae";
      categories = ["Utility" "Accessibility"];
      settings.StartupWMClass = "vicinae";
    };
    xdg.desktopEntries.aionui = {
      name = "AionUi";
      genericName = "AI Agent Desktop";
      comment = "AI Agent 工作台";
      exec = lib.getExe flake.inputs.llm-agents.packages.${system}.aionui;
      icon = "aionui";
      categories = ["Development" "Utility"];
      terminal = false;
    };

    # 激活时补齐菜单项，保留 Favnyr 保存的自定义命令。
    home.activation.favnyrArchiveOpeners = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${seedFavnyrArchiveOpeners} ${lib.escapeShellArg "${config.xdg.dataHome}/favnyr/openers.toml"}
    '';

    # Bitwarden 使用内核 keyring，避免 secretmem 阻止磁盘休眠。
    systemd.user.sessionVariables.SECURE_KEY_CONTAINER_BACKEND = "keyctl";
    systemd.user.services.fcitx5-watchdog = {
      Unit.Description = "Monitor and recover the Fcitx5 input method session";
      Service = {
        Type = "oneshot";
        ExecStart = "${fcitx5Watchdog}";
      };
    };
    systemd.user.timers.fcitx5-watchdog = {
      Unit.Description = "Run the Fcitx5 watchdog periodically";
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "20s";
        Unit = "fcitx5-watchdog.service";
      };
      Install.WantedBy = ["timers.target"];
    };

    # 这些后台服务依赖 WSL 现有的本地配置或账号授权。
    services = {
      ccConnect.enable = false;
      cloudflaredTunnel.enable = false;
      codex2api.enable = false;
      grokOpenAICompat.enable = false;
    };
    home.packages = with pkgs; [
      # 实际试用过 Favnyr、Spacedrive、Sigma File Manager、Xplorer、
      # Strata、Flea 和 Double Commander。Flea 和 Strata 的体验也不错，最终保留 Favnyr。
      (let
        favnyr = flake.inputs.favnyr.packages.${system}.default;
      in
        symlinkJoin {
          pname = "favnyr-with-tools";
          inherit (favnyr) version;
          paths = [favnyr];
          nativeBuildInputs = [makeWrapper];
          postBuild = ''
            # 补齐 Dock 精简环境中可能缺失的应用入口与程序路径。
            wrapProgram "$out/bin/favnyr" \
              --prefix PATH : ${lib.makeBinPath [ffmpeg poppler-utils _7zz favnyrKdeOpenWith]} \
              --suffix PATH : ${lib.escapeShellArg "${config.home.profileDirectory}/bin:${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin"} \
              --suffix XDG_DATA_DIRS : ${lib.escapeShellArg "${config.home.profileDirectory}/share:${config.home.homeDirectory}/.nix-profile/share:/run/current-system/sw/share:${config.xdg.dataHome}/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"}
            desktop=share/applications/favnyr.desktop
            substitute "${favnyr}/$desktop" "$TMPDIR/favnyr.desktop" \
              --replace-fail 'Exec=favnyr ' "Exec=$out/bin/favnyr "
            cp --remove-destination "$TMPDIR/favnyr.desktop" "$out/$desktop"
          '';
        })
      google-chrome
      bitwarden-desktop
      wechat
      qq
      snipaste
      (callPackage ./wps-office.nix {})
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
      (pkgs.callPackage ./weflow.nix {})
      uuRemotePackage
      magpiePackage
      # Magpie Cursor Bridge 需要 certutil 导入用户 NSS 证书库，以及 sqlite3 做数据库检查与清理。
      nssTools
      sqlite
    ];

    # 让 Magpie Cursor Bridge 维护的 cursor-agent-bridge 包装器进入默认 PATH。
    home.sessionPath = ["/home/xmin/.config/magpie-cursor-bridge/bin"];

    # 同时覆盖共享 MIME 类型和 WPS 注册的类型，因为同一扩展名可能被识别为不同类型。
    xdg.configFile."kde-mimeapps.list".text = ''
      [Default Applications]
      inode/directory=org.kde.dolphin.desktop;
      application/pdf=wps-office-pdf.desktop;
      application/msword=wps-office-wps.desktop;
      application/msword-template=wps-office-wps.desktop;
      application/rtf=wps-office-wps.desktop;
      application/vnd.ms-word.document.macroEnabled.12=wps-office-wps.desktop;
      application/vnd.openxmlformats-officedocument.wordprocessingml.document=wps-office-wps.desktop;
      application/vnd.openxmlformats-officedocument.wordprocessingml.template=wps-office-wps.desktop;
      application/wps-office.doc=wps-office-wps.desktop;
      application/wps-office.docx=wps-office-wps.desktop;
      application/wps-office.dot=wps-office-wps.desktop;
      application/wps-office.dotx=wps-office-wps.desktop;
      application/wps-office.wps=wps-office-wps.desktop;
      application/wps-office.wpt=wps-office-wps.desktop;
      application/vnd.ms-excel=wps-office-et.desktop;
      application/vnd.ms-excel.sheet.macroEnabled.12=wps-office-et.desktop;
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet=wps-office-et.desktop;
      application/vnd.openxmlformats-officedocument.spreadsheetml.template=wps-office-et.desktop;
      application/wps-office.xls=wps-office-et.desktop;
      application/wps-office.xlsx=wps-office-et.desktop;
      application/wps-office.xlt=wps-office-et.desktop;
      application/wps-office.xltx=wps-office-et.desktop;
      application/wps-office.et=wps-office-et.desktop;
      application/wps-office.ett=wps-office-et.desktop;
      application/vnd.ms-powerpoint=wps-office-wpp.desktop;
      application/vnd.openxmlformats-officedocument.presentationml.presentation=wps-office-wpp.desktop;
      application/vnd.openxmlformats-officedocument.presentationml.slideshow=wps-office-wpp.desktop;
      application/vnd.openxmlformats-officedocument.presentationml.template=wps-office-wpp.desktop;
      application/wps-office.ppt=wps-office-wpp.desktop;
      application/wps-office.pptx=wps-office-wpp.desktop;
      application/wps-office.pot=wps-office-wpp.desktop;
      application/wps-office.potx=wps-office-wpp.desktop;
      application/wps-office.dps=wps-office-wpp.desktop;
      application/wps-office.dpt=wps-office-wpp.desktop;
      x-scheme-handler/cindy=cindy.desktop;
      x-scheme-handler/xdt-maker=cindy.desktop;
    '';

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
    # XDG autostart 生成的 Fcitx 单元默认 Restart=no。仅添加 drop-in，保留
    # generator 提供的 ExecStart，避免崩溃后输入法长期消失，也避免启动第二个实例。
    xdg.configFile."systemd/user/app-org.fcitx.Fcitx5@autostart.service.d/restart.conf".text = ''
      [Service]
      Restart=on-failure
      RestartSec=2
    '';
    # 阻止 Magpie 生成绕过启动包装的用户级快捷方式。
    xdg.dataFile."applications/magpie.desktop".source = "${magpiePackage}/share/applications/magpie.desktop";
    # Magpie 通过 cindy:// 导入链接打开 Cindy。显式导出桌面入口，避免仅在 profile 中时 GIO 索引不到。
    xdg.dataFile."applications/cindy.desktop".source = "${flake.inputs.llm-agents.packages.${system}.cindy}/share/applications/cindy.desktop";

    # KDE 登录后再启动主机服务，确保 Wayland 会话已就绪。
    xdg.configFile."systemd/user/xdg-desktop-autostart.target.wants/uuremote-native.service" = {
      source = "${uuRemotePackage}/share/systemd/user/uuremote-native.service";
      force = true;
    };
    xdg.configFile."systemd/user/graphical-session.target.wants/uuremote-native.service" = {
      source = "${uuRemotePackage}/share/systemd/user/uuremote-native.service";
      force = true;
    };

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
