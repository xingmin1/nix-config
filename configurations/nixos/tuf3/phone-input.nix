{pkgs, ...}: let
  lanpadSrc = pkgs.fetchFromGitHub {
    owner = "seros-cimenstein";
    repo = "lanpad";
    rev = "e84c4670a7195c16aa7ddca3bd26df8ead9b49b7";
    hash = "sha256-lZElDiiSPbb5UnENnkP3OR7Q7sVODAvtEDcX5yGiMhg=";
  };
  lanpadPython = pkgs.python3.withPackages (ps: [ps.evdev]);
  lanpad = pkgs.writeShellApplication {
    name = "lanpad";
    runtimeInputs = [pkgs.coreutils pkgs.android-tools lanpadPython];
    text = ''
      state="''${XDG_DATA_HOME:-$HOME/.local/share}/lanpad/source"
      if [ ! -f "$state/lanpad.py" ]; then
        mkdir -p "$state"
        cp -R ${lanpadSrc}/. "$state/"
      fi
      exec ${lanpadPython}/bin/python "$state/lanpad.py" "$@"
    '';
  };
  droidpadSrc = pkgs.fetchFromGitHub {
    owner = "lin-calvin";
    repo = "droidpad";
    rev = "4cd340392ac837989fa1fe23250264c38d894e3a";
    hash = "sha256-AhFKUDahvqCKF6DP5cW7okBhMeFTlqYmssB4MKLLGmc=";
  };
  droidpadUdp = pkgs.stdenv.mkDerivation {
    pname = "droidpad-udp";
    version = "0.1.0-4cd3403";
    src = droidpadSrc;
    dontConfigure = true;
    buildPhase = ''
      $CC -O2 -Wall -Wextra -o uhid_udp tools/uhid_udp.c
    '';
    installPhase = ''
      install -Dm755 uhid_udp $out/bin/droidpad-udp
    '';
  };
in {
  boot.kernelModules = ["uinput" "uhid" "hid-multitouch"];

  users.users.xmin.extraGroups = ["input"];
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660"
    KERNEL=="uhid", GROUP="input", MODE="0660"
  '';

  networking.firewall.allowedTCPPorts = [47474];
  networking.firewall.allowedUDPPorts = [47474 9999];

  environment.systemPackages = [
    pkgs.android-tools
    lanpad
    droidpadUdp
  ];

  # 按需运行，避免手机未连接时后台服务反复失败刷日志。
  systemd.user.services.droidpad-udp = {
    description = "DroidPad UDP touchpad bridge";
    serviceConfig = {
      ExecStart = "${droidpadUdp}/bin/droidpad-udp 9999";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
