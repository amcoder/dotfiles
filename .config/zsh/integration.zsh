# FZF
if command -v fzf &> /dev/null; then
  # export FZF_TMUX_OPTS='-p80%,60%'
  export FZF_CTRL_T_OPTS="
    --walker-skip .git,node_modules,target
    --preview 'bat -n --color=always {}'
    --bind 'ctrl-/:change-preview-window(down|hidden|)'"
  export FZF_CTRL_R_OPTS="
    --preview 'echo {}' --preview-window up:3:hidden:wrap
    --bind 'ctrl-/:toggle-preview'
    --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
    --color header:italic
    --header 'Press CTRL-Y to copy command into clipboard'"
  export FZF_ALT_C_OPTS="
    --walker-skip .git,node_modules,target
    --preview 'tree -C {}'"

  fzf --zsh &> /dev/null \
    && source <(fzf --zsh) \
    || source "$XDG_CONFIG_HOME/fzf/fzf.zsh"
fi

# Zoxide
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init --cmd cd zsh)"
fi

# 1Password
if command -v op &> /dev/null; then
  eval "$(op completion zsh)"
  compdef _op op
fi

# direnv
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi
