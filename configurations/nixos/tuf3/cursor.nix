{
  appimageTools,
  code-cursor,
  fetchurl,
}: let
  # 特例：为 Magpie Cursor Bridge 兼容性，手动锁定在 3.30 系列的最新版本。
  # https://github.com/kingchen95272025/magpie-agent-cursor-bridge-enhanced
  version = "3.30.14";
  appImage = fetchurl {
    url = "https://downloads.cursor.com/production/5f54c8173e5552412beb40702adac16275677fa0/linux/x64/Cursor-${version}-x86_64.AppImage";
    hash = "sha256-6gfkPW9kEnXIhd4LqzZXVBEMVyH+hSTNuDtoUIDoq7k=";
  };
  ripgrepPath = "@cursor/ripgrep-linux-x64/bin/rg";
in
  code-cursor.overrideAttrs (finalAttrs: oldAttrs: {
    inherit version;
    src = appimageTools.extract {
      inherit (finalAttrs) pname version;
      src = appImage;
    };
    sourceRoot = "${finalAttrs.pname}-${version}-extracted/usr/share/cursor";

    # 让 Nixpkgs 的搜索组件替换步骤使用此版本的实际路径。
    postPatch =
      builtins.replaceStrings
      ["@vscode/ripgrep/bin/rg" "@vscode/ripgrep-universal/bin/linux-x64/rg"]
      [ripgrepPath ripgrepPath]
      oldAttrs.postPatch;
  })
