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

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in zsh plugins
zinit light romkatv/zsh-defer
zinit ice depth=1; zinit light romkatv/powerlevel10k
zsh-defer zinit light zsh-users/zsh-syntax-highlighting
zsh-defer zinit light zsh-users/zsh-completions
zsh-defer zinit light zsh-users/zsh-autosuggestions
zsh-defer zinit light zsh-users/zsh-history-substring-search
zsh-defer zinit light Aloxaf/fzf-tab

# Add in snippets
zsh-defer zinit snippet OMZP::sudo
zsh-defer zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit
zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Keybindings
bindkey -v
bindkey "$key[Up]" history-substring-search-up
bindkey "$key[Down]" history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# Edit command line
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# show hidden files
setopt globdots

# Completion styling
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':completion:*' matcher-list '' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*:*:*:*:descriptions' format '%d'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompcache"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

if command -v fzf &> /dev/null; then
  export FZF_TMUX_OPTS='-p80%,60%'
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

if command -v zoxide &> /dev/null; then
  zsh-defer eval "$(zoxide init --cmd cd zsh)"
fi

if command -v op &> /dev/null; then
  zsh-defer eval "$(op completion zsh)"
  compdef _op op
fi

if command -v direnv &> /dev/null; then
  zsh-defer eval "$(direnv hook zsh)"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && zsh-defer \. "$NVM_DIR/nvm.sh"  # This loads nvm

[ -f ~/.aliases ] && source ~/.aliases

[ -f ~/.zshrc.local ] && source ~/.zshrc.local

export _ZSHRC_LOADED=$(( ${_ZSHRC_LOADED:-0} + 1 ))
