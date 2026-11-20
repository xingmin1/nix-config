# Like GNU `make`, but `just` rustier.
# https://just.systems/
# run `just` from this directory to see available commands

# Default command when 'just' is run without arguments
default:
  @just --list

# Update nix flake
[group('Main')]
update: update-weflow
  nix flake update

# 从 GitHub 最新正式发行版锁定 WeFlow 的版本和 Linux 资产校验值。
[group('Main')]
update-weflow:
  #!/usr/bin/env bash
  set -euo pipefail
  manifest=configurations/nixos/tuf3/weflow-release.json
  temporary=$(mktemp "$manifest.XXXXXX")
  trap 'rm -f "$temporary"' EXIT
  curl --fail --silent --show-error --location --retry 2 --max-time 30 \
    https://api.github.com/repos/334456777/WeFlow/releases/latest |
    jq --exit-status '
      .tag_name as $tag | .assets as $assets |
      if ($tag | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) then
        {tag: $tag, sha256: (reduce ["x64", "arm64"][] as $arch ({};
          [$assets[] | select(.name == ("weflow-" + $tag + "-linux-" + $arch + ".tar.gz")) |
            .digest | select(type == "string" and test("^sha256:[0-9a-f]{64}$")) |
            sub("^sha256:"; "")] as $hashes |
          if ($hashes | length) == 1 then .[$arch] = $hashes[0]
          else error("WeFlow 缺少有效的 Linux " + $arch + " 校验值") end
        ))}
      else error("WeFlow 的发行标签无效") end
    ' > "$temporary"
  chmod 644 "$temporary"
  mv -- "$temporary" "$manifest"

# Lint nix files
[group('dev')]
lint:
  nix fmt

# Check nix flake
[group('dev')]
check:
  nix flake check

# Manually enter dev shell
[group('dev')]
dev:
  nix develop

# Activate the configuration
[group('Main')]
run:
  nix run
