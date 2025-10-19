{
  # 迁移自 khanelinix：Nushell 配置（重用 Home Manager 的 shellAliases）。
  #
  # 适配说明：
  # - 去除自定义 options；保留对 home.shellAliases 的转换以兼容 nu 的语法。
  config,
  lib,
  ...
}:
{
  programs.nushell = {
    enable = true;

    # 将 bash/zsh 风格的别名转换为 nushell 语法
    shellAliases = lib.mkForce (
      lib.mapAttrs (
        _name: value:
        let
          isComplexScript =
            lib.hasInfix "\n" value && (lib.hasInfix "for " value || lib.hasInfix "if " value);
          hasPositionalParams =
            let
              hasBasicPositionalParams =
                lib.hasInfix "$1" value || lib.hasInfix "$2" value || lib.hasInfix "$@" value;
              isAwkFieldReference = lib.hasInfix "{print $1}" value || lib.hasInfix "'{print $1}'" value;
            in
            hasBasicPositionalParams && !isAwkFieldReference;
          hasMultipleCommands = lib.hasInfix "&&" value || lib.hasInfix "||" value || lib.hasInfix ";" value;

          transformedValue =
            if isComplexScript || hasPositionalParams || hasMultipleCommands then
              let
                lines = lib.splitString "\n" value;
                nonCommentLines = builtins.filter (
                  line:
                  let trimmed = lib.trim line; in trimmed != "" && !lib.hasPrefix "#" trimmed
                ) lines;
                cleanScript = lib.concatStringsSep "\n" nonCommentLines;
              in
              if hasPositionalParams then
                let functionScript = "f() { " + cleanScript + "; }; f \"$@\""; in
                "bash -c " + lib.escapeShellArg functionScript + " --"
              else
                "bash -c '" + (lib.replaceStrings [ "'" ] [ "'\"'\"'" ] cleanScript) + "'"
            else
              let
                words = lib.splitString " " value;
                conflictingCommands = [ "find" "grep" "sort" "uniq" "head" "tail" "cut" "wc" ];
                transformedWords = builtins.map (word: if builtins.elem word conflictingCommands then "command " + word else word) words;
                withCommandPrefix = lib.concatStringsSep " " transformedWords;
                parts = lib.splitString "$" withCommandPrefix;
                withEnvVars = lib.concatStrings (
                  lib.imap0 (
                    i: part:
                    if i == 0 then part
                    else if lib.hasPrefix "(" part then "$" + part
                    else if builtins.match "^[A-Za-z_][A-Za-z0-9_]*.*" part != null then "$env." + part
                    else "$" + part
                  ) parts
                );
              in
              withEnvVars;
        in
        transformedValue
      ) config.home.shellAliases
    );
  };
}

