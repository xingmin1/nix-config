{
  # 迁移自 khanelinix：Zsh 配置（插件、补全与交互行为）。
  #
  # 适配说明：
  # - 移除了自定义 options（khanelinix.*），改为直接启用 programs.zsh。
  # - 依赖 Atuin 的可选逻辑已改为检测 config.programs.atuin.enable。
  # - 去除了 fastfetch 相关引用，避免未定义选项导致的评估失败。
  config,
  lib,
  pkgs,

  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.strings) fileContents;
in
{
  programs = {
    zsh = {
      enable = true;
      package = pkgs.zsh;

      autocd = true;

      setOptions = [
        # Enable options
        "AUTO_LIST"
        "AUTO_PARAM_SLASH"
        "AUTO_PUSHD"
        "ALWAYS_TO_END"
        "CORRECT"
        "INTERACTIVE_COMMENTS"

        "PUSHD_IGNORE_DUPS"
        "PUSHD_TO_HOME"
        "PUSHD_SILENT"
        "NOTIFY"
        "PROMPT_SUBST"
        "MULTIOS"
        "NOFLOWCONTROL"

        # Disable options (prefix with NO_)
        "NO_CORRECT_ALL"
        "NO_NOMATCH"
      ]
      # 当未启用 Atuin 时使用 Zsh 原生历史优化
      ++ lib.optionals (!config.programs.atuin.enable or false) [
        "HIST_VERIFY"
        "NO_HIST_BEEP"
      ];

      completionInit =
        ''
          # 加载 compinit 并优化编译缓存
          autoload -U compinit
          zmodload zsh/complist

          _comp_options+=(globdots)
          zcompdump="$XDG_DATA_HOME"/zsh/.zcompdump-"$ZSH_VERSION"-"$(date --iso-8601=date)"
          compinit -d "$zcompdump"

          if [[ -s "$zcompdump" && (! -s "$zcompdump".zwc || "$zcompdump" -nt "$zcompdump".zwc) ]]; then
            zcompile "$zcompdump"
          fi

          # 兼容 bash 补全（供部分命令复用 bash completion 脚本）
          autoload -U +X bashcompinit && bashcompinit

          ${fileContents ./rc/comp.zsh}
        '';

      dotDir = "${config.xdg.configHome}/zsh";
      enableCompletion = true;
      enableVteIntegration = true;

      # 禁用系统级 zshrc/zprofile 的默认行为，确保用户配置优先
      envExtra = mkIf pkgs.stdenv.hostPlatform.isLinux ''
        setopt no_global_rcs
      '';

      history = mkIf (!config.programs.atuin.enable or false) {
        path = "${config.xdg.dataHome}/zsh/zsh_history";
        extended = true;
        save = 100000;
        size = 100000;
        expireDuplicatesFirst = true;
        ignoreDups = true;
        ignoreSpace = true;
        saveNoDups = true;
        findNoDups = true;
      };

      sessionVariables = {
        LC_ALL = "en_US.UTF-8";
        KEYTIMEOUT = 0;
      };

      # 与上游一致：不用 HM 自带 syntaxHighlighting，而用 fast-syntax-highlighting 插件
      # 由于 modules/home/shell.nix 也设置过 enable=true，这里使用 mkForce 关闭以消除冲突
      syntaxHighlighting.enable = lib.mkForce false;

      initContent = lib.mkMerge [
        (lib.mkOrder 450 (
          lib.optionalString (!config.programs.atuin.enable or false)
            ''
              # 将上一条成功的命令写入历史（搭配 autosuggestion 使用）
              function zshaddhistory() {
                LASTHIST=''${1//\\$'\n'/}
                return 2
              }

              function precmd() {
                if [[ $? == 0 && -n ''${LASTHIST//[[:space:]\n]/} && -n $HISTFILE ]] ; then
                  print -sr -- ''${=''${LASTHIST%%'\n'}}
                fi
              }

              if autoload history-search-end; then
                zle -N history-beginning-search-backward-end history-search-end
                zle -N history-beginning-search-forward-end  history-search-end
              fi
            ''
        ))

        (lib.mkOrder 500 ''
          source <(${lib.getExe config.programs.fzf.package} --zsh)
          source ${config.programs.git.package}/share/git/contrib/completion/git-prompt.sh
        '')

        (lib.mkOrder 600 ''
          ${fileContents ./rc/binds.zsh}
          ${fileContents ./rc/modules.zsh}
          ${fileContents ./rc/fzf-tab.zsh}
          ${fileContents ./rc/misc.zsh}

          ${lib.optionalString (!config.programs.atuin.enable or false) ''
            ZSH_AUTOSUGGEST_HISTORY_IGNORE=$'*\n*'
          ''}
        '')

        # 应为最后执行项：不再自动运行 fastfetch，避免未声明依赖
      ];

      plugins = [
        {
          name = "fzf-tab";
          file = "share/fzf-tab/fzf-tab.plugin.zsh";
          src = pkgs.zsh-fzf-tab;
        }
        {
          name = "zsh-nix-shell";
          file = "share/zsh-nix-shell/nix-shell.plugin.zsh";
          src = pkgs.zsh-nix-shell;
        }
        {
          name = "zsh-vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
        {
          name = "fast-syntax-highlighting";
          file = "share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh";
          src = pkgs.zsh-fast-syntax-highlighting;
        }
        {
          name = "zsh-autosuggestions";
          file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
          src = pkgs.zsh-autosuggestions;
        }
        {
          name = "zsh-better-npm-completion";
          file = "share/zsh-better-npm-completion";
          src = pkgs.zsh-better-npm-completion;
        }
        {
          name = "zsh-command-time";
          file = "share/zsh/plugins/zsh-command-time/zsh-command-time.plugin.zsh";
          src = pkgs.zsh-command-time;
        }
        {
          name = "zsh-you-should-use";
          file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
          src = pkgs.zsh-you-should-use;
        }
      ];
    };
  };
}
