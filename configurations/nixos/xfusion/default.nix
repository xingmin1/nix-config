# This file is just *top-level* configuration.
{flake, ...}: let
  inherit (flake) inputs;
  inherit (inputs) self;
in {
  imports = [
    self.nixosModules.default
  ];

  nix.settings.substituters = [
    "http://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "http://mirror.sjtu.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://nix-community.cachix.org"
  ];
  # will be appended to the system-level trusted-public-keys
  nix.settings.extra-trusted-public-keys = [
    # nix community's cache server public key
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
  networking.hostName = "xfusion";

  security.sudo = {
    enable = true; # 启用 sudo，并由 NixOS 生成 /etc/sudoers
    extraConfig = ''
      Defaults env_keep += "http_proxy https_proxy no_proxy"
      Defaults env_keep += "HTTP_PROXY HTTPS_PROXY NO_PROXY"
      Defaults env_keep += "all_proxy ALL_PROXY"
      Defaults env_keep += "NIX_SSL_CERT_FILE SSL_CERT_FILE GIT_SSL_CAINFO CURL_CA_BUNDLE"
    '';
  };

  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
      MIIDXjCCAkYCCQCZVibT7yLrnjANBgkqhkiG9w0BAQUFADBwMQswCQYDVQQGEwJD
      TjERMA8GA1UEBxMIU2hlbnpoZW4xEDAOBgNVBAoTB1hmdXNpb24xCzAJBgNVBAsT
      AklUMS8wLQYDVQQDEyZYZnVzaW9uIFdlYiBTZWN1cmUgSW50ZXJuZXQgR2F0ZXdh
      eSBDQTAgFw0yMTEwMTkwOTIxMDhaGA8yMDcxMTAwNzA5MjEwOFowcDELMAkGA1UE
      BhMCQ04xETAPBgNVBAcTCFNoZW56aGVuMRAwDgYDVQQKEwdYZnVzaW9uMQswCQYD
      VQQLEwJJVDEvMC0GA1UEAxMmWGZ1c2lvbiBXZWIgU2VjdXJlIEludGVybmV0IEdh
      dGV3YXkgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDiS+bD33LL
      UmLpWhlQYthMq6ugBD7qhYvykjafIG/ZeUYi0rtdPX0h0V8b1k2gQMIINFeQ0QWv
      0tG8zB9dNUnAXFRSf/htDmGiSkLSijjhD8yzrLdbKm/lS4H5hfji7OHfDcNRyfzp
      JWxYwPLhd+sCz4xusEOqTjQmfebdRjYyq4uX8yswfHwj+JjMP0eP0iVFYrSZAXAL
      DJ1Y1hQIl7PbLS6GNrCo7nsT5k2V0Cw2i7TAAjoHAD/EEM+FMA9T/Ep/L2P6Alqx
      oe8qqHSrfB+MhnLMWDMb3CEvG4n2D0lh1e9fgvfaDkgH1fMzznB0qCxcVF6F1I9c
      YOmoN0IxfjrvAgMBAAEwDQYJKoZIhvcNAQEFBQADggEBAIaRw2RWTRAlQwJGhTrK
      uUnGwDw2cXA3qiynlGkdSobsd6rYgc0adYkitVQwFbVrt2SZDDDy9eDhiYwOLHdg
      vOxJkmZA7uE9aCdCdLdeGMv0MQRJ/PEg9wyOfZ3a2TZ9pxV9p3EnKHX+unPscf/G
      MjXuhLEOSRw95aQkgJKvqY9f7amIoKka2waof4M2Skc6CWkFvidHrQX4XFd5xCqy
      J+gDlppjBJVGvFAA3gfSoGAb+Wmlq/UIBudI5EmfNC3KZQimkiHksdedY18uW9PL
      99PTjEaQizGMEBuw2Ik713/hyzNALcV61Zeph4TTMW3DB3UcOdd9slOOEeBtYRp/
      Ntk=
      -----END CERTIFICATE-----
    ''
  ];
}
