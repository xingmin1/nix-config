{
  pkgs,
  lib,
  ...
}: let
  windowsPowerShell = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe";
  windowsClip = "/mnt/c/Windows/System32/clip.exe";
  windowsClipboardRead = "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; Get-Clipboard -Raw";
  windowsClipboardSet = pkgs.writeShellApplication {
    name = "hx-clipboard-set";
    runtimeInputs = [
      pkgs.glibc.bin
    ];
    text = ''
      set -euo pipefail

      iconv -f UTF-8 -t UTF-16LE | ${lib.escapeShellArg windowsClip}
    '';
  };
  windowsClipboardGet = pkgs.writeShellApplication {
    name = "hx-clipboard-get";
    runtimeInputs = [
      pkgs.gnused
    ];
    text = ''
      set -euo pipefail

      ${lib.escapeShellArg windowsPowerShell} \
        -NoProfile \
        -NonInteractive \
        -Command ${lib.escapeShellArg windowsClipboardRead} \
        | sed 's/\r$//'
    '';
  };
  windowsClipboardReadCommand = {
    command = "${windowsClipboardGet}/bin/hx-clipboard-get";
    args = [];
  };
  windowsClipboardWriteCommand = {
    command = "${windowsClipboardSet}/bin/hx-clipboard-set";
    args = [];
  };
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
        # Helix 自定义 provider 中，yank 命令向 Helix 输出内容，paste 命令接收 Helix 的 stdin。
        clipboard-provider.custom = {
          yank = windowsClipboardReadCommand;
          paste = windowsClipboardWriteCommand;
          primary-yank = windowsClipboardReadCommand;
          primary-paste = windowsClipboardWriteCommand;
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
