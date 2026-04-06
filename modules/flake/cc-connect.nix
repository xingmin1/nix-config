{inputs, ...}: let
  releaseMeta = builtins.fromJSON (builtins.readFile inputs.ccConnectBeta);
  version = releaseMeta.version;
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    platformInfo =
      {
        x86_64-linux = {
          os = "linux";
          arch = "amd64";
        };
        aarch64-linux = {
          os = "linux";
          arch = "arm64";
        };
        x86_64-darwin = {
          os = "darwin";
          arch = "amd64";
        };
        aarch64-darwin = {
          os = "darwin";
          arch = "arm64";
        };
      }
        .${
        system
      }
        or (throw "cc-connect: 不支持的系统 ${system}");

    assetBaseName = "cc-connect-v${version}-${platformInfo.os}-${platformInfo.arch}";
    assetName = "${assetBaseName}.tar.gz";
    githubUrl = "https://github.com/chenhg5/cc-connect/releases/download/v${version}/${assetName}";
    giteeUrl = "https://gitee.com/cg33/cc-connect/releases/download/v${version}/${assetName}";
  in {
    packages.cc-connect = pkgs.writeShellApplication {
      name = "cc-connect";
      runtimeInputs = with pkgs; [
        coreutils
        curl
        gnutar
      ];
      text = ''
        set -euo pipefail

        version='${version}'
        asset_base_name='${assetBaseName}'
        asset_name='${assetName}'
        github_url='${githubUrl}'
        gitee_url='${giteeUrl}'

        install_root="''${XDG_DATA_HOME:-$HOME/.local/share}/cc-connect"
        binary_dir="$install_root/$version"
        binary_path="$binary_dir/cc-connect"

        if [ ! -x "$binary_path" ]; then
          tmp_dir="$(mktemp -d)"
          archive_path="$tmp_dir/$asset_name"
          extract_dir="$tmp_dir/extract"
          downloaded=0

          cleanup() {
            rm -rf "$tmp_dir"
          }
          trap cleanup EXIT

          mkdir -p "$extract_dir" "$binary_dir"

          for url in "$github_url" "$gitee_url"; do
            rm -f "$archive_path"
            if curl -fL --retry 3 --connect-timeout 10 -o "$archive_path" "$url"; then
              downloaded=1
              break
            fi
          done

          if [ "$downloaded" -ne 1 ]; then
            echo "cc-connect: 下载 ${version} 失败，已尝试 GitHub 与 Gitee 镜像。" >&2
            exit 1
          fi

          tar -xzf "$archive_path" -C "$extract_dir"

          if [ ! -f "$extract_dir/$asset_base_name" ]; then
            echo "cc-connect: 解压后的二进制不存在：$extract_dir/$asset_base_name" >&2
            exit 1
          fi

          install -Dm755 "$extract_dir/$asset_base_name" "$binary_path"
        fi

        exec "$binary_path" "$@"
      '';
      meta = {
        description = "通过 flake.lock 跟踪 npm beta 元数据的 cc-connect 启动器";
        homepage = "https://github.com/chenhg5/cc-connect";
        license = pkgs.lib.licenses.mit;
        mainProgram = "cc-connect";
        platforms = pkgs.lib.platforms.unix;
      };
    };
  };
}
