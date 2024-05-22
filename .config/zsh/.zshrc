# This is loaded after .zshenv and .zlogin for interactive shells
# Load order:
# - .zshenv
# - .zprofile (login only)
# - .zshrc (interactive only)
# - .zlogin (login only)
# - .zlogout (logout only)

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[ -d "$ZSH_CACHE_DIR" ] || mkdir -p "$ZSH_CACHE_DIR"
ZSH_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh"
[ -d "$ZSH_DATA_DIR" ] || mkdir -p "$ZSH_DATA_DIR"
ZSH_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
[ -d "$ZSH_STATE_DIR" ] || mkdir -p "$ZSH_STATE_DIR"

# Setup zinit
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Plugins
zinit light romkatv/zsh-defer
zinit ice depth=1; zinit light romkatv/powerlevel10k
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-history-substring-search
zinit light Aloxaf/fzf-tab

# Snippets
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found

# Compinit
autoload -Uz compinit && compinit -d "${ZSH_CACHE_DIR}/zcompdump"
zinit cdreplay -q

# Powerlevel10k
if [ $TERM = "linux" ]; then
  [[ ! -f "$ZDOTDIR/p10k.pure.zsh" ]] || source "$ZDOTDIR/p10k.pure.zsh"
else
  [[ ! -f "$ZDOTDIR/p10k.zsh" ]] || source "$ZDOTDIR/p10k.zsh"
fi

# Keybindings
bindkey -v
bindkey "$key[Up]" history-substring-search-up
bindkey "$key[Down]" history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# Edit command line
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'vv' edit-command-line
bindkey -rM viins '^[^['
bindkey -rM vicmd '^[^['
bindkey -M viins '^[s' sudo-command-line
bindkey -M vicmd '^[s' sudo-command-line

# History
HISTSIZE=100000
HISTFILE="${ZSH_STATE_DIR}/history"
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt append_history
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_ignore_dups
setopt hist_save_no_dups
setopt hist_find_no_dups

# cd and pushd
setopt auto_cd
setopt cdable_vars
setopt cd_silent
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushd_silent
setopt pushd_to_home

# Completion
zstyle ':completion:*' menu no
zstyle ':completion:*' matcher-list '' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${ZSH_CACHE_DIR}/zcompcache"
zstyle ':completion:*:*:*:*:descriptions' format '[%d]'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
_comp_options+=(globdots)

# Named directories
if [ -d "$HOME/projects/transact" ]; then
  for dir in $HOME/projects/transact/*/; do
    hash -d "${${dir:t}##(bb-ea-|eaevo-(ui-|api-|))}"="${dir%/}"
  done
fi

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

  source <(fzf --zsh)
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

# NVM
[ -d "$XDG_CONFIG_HOME/nvm" ] && export NVM_DIR="$XDG_CONFIG_HOME/nvm"
[ -d "$HOME/.nvm" ] && export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && zsh-defer \. "$NVM_DIR/nvm.sh"

# Aliases
[ -f "$ZDOTDIR/.aliases" ] && source "$ZDOTDIR/.aliases"

[ -f ~/.zshrc.local ] && source ~/.zshrc.local
