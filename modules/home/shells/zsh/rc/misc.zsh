## 杂项调整（完整迁移自 khanelinix）
# 开启 keyword-style 参数
set -k

autoload -Uz colors && colors

# Autosuggest
ZSH_AUTOSUGGEST_USE_ASYNC="true"
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# 打开命令于 $EDITOR
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^e" edit-command-line
zmodload zsh/zle
zmodload zsh/zpty
