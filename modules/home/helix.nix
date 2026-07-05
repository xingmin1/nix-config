{
  pkgs,
  lib,
  ...
}: let
  clipboardReadCommand = {
    command = lib.getExe' pkgs.wl-clipboard "wl-paste";
    args = ["--no-newline"];
  };
  clipboardWriteCommand = {
    command = lib.getExe' pkgs.wl-clipboard "wl-copy";
    args = [];
  };
  primaryClipboardReadCommand = clipboardReadCommand // {args = ["--primary" "--no-newline"];};
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
        # WSLg 会把 Wayland 剪贴板与 Windows 剪贴板同步，避免依赖易失效的 Windows 进程互操作。
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
