{
  pkgs,
  lib,
  ...
}: let
  waylandClipboardGet = lib.getExe' pkgs.wl-clipboard "wl-paste";
  waylandClipboardSet = lib.getExe' pkgs.wl-clipboard "wl-copy";
  windowsPowerShell = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe";
  windowsClip = "/mnt/c/Windows/System32/clip.exe";
  windowsClipboardRead = "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; [Console]::Out.Write((Get-Clipboard -Raw))";
  clearStaleWindowsInterop = ''
    clearStaleWindowsInterop() {
      if [[ -n "''${WSL_INTEROP-}" && ! -S "$WSL_INTEROP" ]]; then
        unset WSL_INTEROP
      fi
    }
  '';
  clipboardGet = pkgs.writeShellApplication {
    name = "hx-clipboard-get";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      set -euo pipefail

      ${clearStaleWindowsInterop}

      selectionArgs=()
      if [[ "''${1-}" == "--primary" ]]; then
        selectionArgs=(--primary)
      fi

      clipboardContent="$(mktemp)"
      trap 'rm -f "$clipboardContent"' EXIT

      if ${lib.escapeShellArg waylandClipboardGet} \
        "''${selectionArgs[@]}" \
        --no-newline \
        > "$clipboardContent" \
        2>/dev/null; then
        cat "$clipboardContent"
        exit 0
      fi

      if [[ ! -x ${lib.escapeShellArg windowsPowerShell} ]]; then
        echo "Wayland 和 Windows 剪贴板均不可用" >&2
        exit 1
      fi

      clearStaleWindowsInterop

      ${lib.escapeShellArg windowsPowerShell} \
        -NoLogo \
        -NoProfile \
        -NonInteractive \
        -Command ${lib.escapeShellArg windowsClipboardRead} \
        | sed 's/\r$//'
    '';
  };
  clipboardSet = pkgs.writeShellApplication {
    name = "hx-clipboard-set";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.glibc.bin
    ];
    text = ''
      set -euo pipefail

      ${clearStaleWindowsInterop}

      selectionArgs=()
      if [[ "''${1-}" == "--primary" ]]; then
        selectionArgs=(--primary)
      fi

      clipboardContent="$(mktemp)"
      trap 'rm -f "$clipboardContent"' EXIT
      cat > "$clipboardContent"

      if ${lib.escapeShellArg waylandClipboardSet} \
        "''${selectionArgs[@]}" \
        --type text/plain \
        < "$clipboardContent" \
        2>/dev/null; then
        exit 0
      fi

      if [[ ! -x ${lib.escapeShellArg windowsClip} ]]; then
        echo "Wayland 和 Windows 剪贴板均不可用" >&2
        exit 1
      fi

      clearStaleWindowsInterop

      iconv -f UTF-8 -t UTF-16LE < "$clipboardContent" \
        | ${lib.escapeShellArg windowsClip}
    '';
  };
  clipboardReadCommand = {
    command = lib.getExe clipboardGet;
    args = [];
  };
  clipboardWriteCommand = {
    command = lib.getExe clipboardSet;
    args = [];
  };
  primaryClipboardReadCommand = clipboardReadCommand // {args = ["--primary"];};
  primaryClipboardWriteCommand = clipboardWriteCommand // {args = ["--primary"];};
in {
  programs.helix = {
    enable = true;
    package = pkgs.helix;
    languages = {
      language = [
        {
          name = "python";
          auto-format = true;
          language-servers = [
            "ruff"
          ];
        }
      ];
      language-server = {
        ruff = {
          command = lib.getExe pkgs.ruff;
          args = ["server"];
        };
      };
    };
    settings = {
      editor = {
        line-number = "relative";
        cursorline = true;
        color-modes = true;
        lsp.display-messages = true;
        # WSLg 偶尔会留下无监听者的 Wayland 套接字，此时自动回退到 Windows 剪贴板。
        clipboard-provider.custom = {
          yank = clipboardReadCommand;
          paste = clipboardWriteCommand;
          primary-yank = primaryClipboardReadCommand;
          primary-paste = primaryClipboardWriteCommand;
        };
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        indent-guides.render = true;
      };
      keys.normal = {
        space = {
          space = "file_picker";
          w = ":w";
          q = ":q";
        };
        esc = [
          "collapse_selection"
          "keep_primary_selection"
        ];
      };
    };
  };
}
