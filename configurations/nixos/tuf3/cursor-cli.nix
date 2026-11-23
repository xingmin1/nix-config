{
  cursor-cli,
  fetchurl,
  stdenv,
}:
# 固定 Cursor CLI 到 Magpie Cursor Bridge 已实测兼容的版本（2026.11.19-f005e9d），
# 避免 nixpkgs 版本滞后触发协议兼容性告警。
cursor-cli.overrideAttrs (old: {
  version = "2026.11.19-f005e9d";

  src =
    if stdenv.hostPlatform.system == "x86_64-linux"
    then
      fetchurl {
        url = "https://downloads.cursor.com/lab/2026.11.19-f005e9d/linux/x64/agent-cli-package.tar.gz";
        hash = "sha256-olmG6vDJMwru7FmaE5cRy58mfGRWLQc6crdR7fUWFpU=";
      }
    else old.src;

  # Home Manager 管理的 ~/.bashrc 与 .zshrc 为只读软链，插件无法直接写入 shell hook。
  # 在 Nix 包装脚本中按需加载 agent-env，可让 bash/zsh/子进程统一经由桥接代理访问网关，
  # 同时将 HTTPS_PROXY 作用域限制在 cursor-agent 进程内，不污染交互式 shell。
  # 如需临时直连官方服务端，可设置 CURSOR_BRIDGE_DIRECT=1。
  postInstall =
    (old.postInstall or "")
    + ''
      rm -f "$out/bin/cursor-agent"
      cat > "$out/bin/cursor-agent" <<'EOF'
      #!/bin/sh
      if [ -z "''${CURSOR_BRIDGE_DIRECT:-}" ]; then
        _bridge_env="''${XDG_CONFIG_HOME:-$HOME/.config}/magpie-cursor-bridge/agent-env"
        if [ -f "$_bridge_env" ]; then
          . "$_bridge_env"
        fi
      fi
      EOF
      printf 'exec "%s/share/cursor-agent/cursor-agent" "$@"\n' "$out" >> "$out/bin/cursor-agent"
      chmod +x "$out/bin/cursor-agent"
    '';
})
