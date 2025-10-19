## 补全集合（完整迁移自 khanelinix）
zstyle ':completion:*' insert-tab pending

# Group matches and describe.
zstyle ':completion:*' sort false
zstyle ':completion:complete:*:options' sort false
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*'
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s

zstyle ':completion:*' rehash true
zstyle ':completion:*:jobs' numbers true
zstyle ':completion:*:jobs' verbose true
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'
zstyle ':completion:*' insert-tab false
zstyle ':completion:*:approximate:' max-errors 'reply=( $((($#PREFIX+$#SUFFIX)/3 )) numeric )'
zstyle ':completion:*:correct:*' insert-unambiguous true
zstyle ':completion:*:corrections' format $'%{\e[0;31m%}%d (errors: %e)%{\e[0m%}'
zstyle ':completion:*:correct:*' original true
zstyle ':completion:*' list-dirs-first true
zstyle ':completion:*' original true
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*:expand:*' tag-order all-expansions
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:processes' command 'ps -a -u $USER'
zstyle ':completion::(^approximate*):*:functions' ignored-patterns '_*'
zstyle ':completion:*:processes-names' command 'ps c -u ${USER} -o command | uniq'
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.*' insert-sections true
zstyle ':completion:*:man:*' menu yes select
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' special-dirs ..
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR"
zstyle ':completion:*' path-completion false
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
# Fzf-tab & 其他增强（完整迁移自 khanelinix）
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions'   format '[%d]'
zstyle ':completion:*'                list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*'                menu no
zstyle ':fzf-tab:complete:cd:*'       fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:*'                   switch-group '<' '>'
zstyle ':fzf-tab:complete:cd:*'       popup-pad 20 0
zstyle ':completion:*'                file-sort modification
zstyle ':completion:*:eza'            sort false
zstyle ':completion:files'            sort false

# 终端标题 & TIMEFMT
case "$TERM" in
xterm* | rxvt* | Eterm | aterm | kterm | gnome* | alacritty | kitty*)
  TERM_TITLE=$'\e]0;%n@%m: %1~\a'
  ;;
*) ;;
esac

# 时间统计格式（time 命令）
TIMEFMT=$'\033[1m[%J]\033[0m: %uU user | %uS system | %uE/%*E elapsed | %P CPU\n> (%X avgtext + %D avgdata + %M maxresident)k used\n> [%I inputs / %O outputs] | (%Fmajor + %Rminor) pagefaults | %W swaps'
