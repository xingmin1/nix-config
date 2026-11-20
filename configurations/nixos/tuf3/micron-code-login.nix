{pkgs, ...}: {
  systemd.services.micron-code-login = {
    description = "Mount the Micron code directory when xmin logs in";
    wantedBy = ["user@1000.service"];
    after = ["user@1000.service"];
    path = [pkgs.coreutils pkgs.systemd pkgs.util-linux];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "25s";
    };
    script = ''
      set -eu
      source=/mnt/micron-code
      target=/home/xmin/code
      expected=20bdc11a-b3af-4b54-bac0-af4a137395cb

      if findmnt -rn -M "$target" >/dev/null; then
        test "$(findmnt -rn -t ext4 -M "$target" -o UUID)" = "$expected"
        exit
      fi
      test ! -L "$target"
      if [ ! -e "$target" ]; then
        install -d -m0000 -o root -g root "$target"
      fi
      test -d "$target"
      test "$(stat -c '%u:%g:%a' "$target")" = 0:0:0
      systemctl start "$(systemd-escape --path --suffix=mount "$source")"
      test "$(findmnt -rn -t ext4 -M "$source" -o UUID)" = "$expected"
      test -d "$source/code"
      systemctl start home-xmin-code.mount
      test "$(findmnt -rn -t ext4 -M "$target" -o UUID)" = "$expected"
    '';
  };
}
