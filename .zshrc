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

# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh
ZSH_CUSTOM=$HOME/.oh-my-zsh.custom

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set to this to use case-sensitive completion
CASE_SENSITIVE="true"

# Uncomment following line if you want to disable command autocorrection
DISABLE_CORRECTION="true"

# enable agent forwarding
zstyle :omz:plugins:ssh-agent agent-forwarding on

# Pass unmatched extended globs to the command
unsetopt nomatch

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# basic zsh plugins
plugins=(vi-mode history-substring-search ssh-agent colored-man-pages)

# linux plugins
if [ "`uname -a`" =~ "Debian" ]; then
  plugins=($plugins debian)
fi
if [ "`uname -a`" =~ "Ubuntu" ]; then
  plugins=($plugins ubuntu)
fi

# mac plugins
if [ `uname` = "Darwin" ]; then
  plugins=($plugins brew)
fi

# Development plugins
plugins=($plugins git docker docker-compose dotnet gradle)
if [ -d $HOME/.jenv/bin ]; then
  plugins=($plugins jenv)
fi

source $ZSH/oh-my-zsh.sh

fpath+=${ZDOTDIR:-~}/.oh-my-zsh.custom/completions

zle -N edit-command-line
bindkey -M vicmd v edit-command-line

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Keypad
# 0 . Enter
bindkey -s "^[Op" "0"
bindkey -s "^[On" "."
bindkey -s "^[OM" "^M"
# 1 2 3
bindkey -s "^[Oq" "1"
bindkey -s "^[Or" "2"
bindkey -s "^[Os" "3"
# 4 5 6
bindkey -s "^[Ot" "4"
bindkey -s "^[Ou" "5"
bindkey -s "^[Ov" "6"
# 7 8 9
bindkey -s "^[Ow" "7"
bindkey -s "^[Ox" "8"
bindkey -s "^[Oy" "9"
# + -  * / =
bindkey -s "^[Ok" "+"
bindkey -s "^[Om" "-"
bindkey -s "^[Oj" "*"
bindkey -s "^[Oo" "/"
bindkey -s "^[OX" "="

# enable color support of ls and also add handy aliases on GNU machines
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

if [ -d /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc ]; then
  source /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc
fi

if command -v direnv &> /dev/null; then
  export DIRENV_LOG_FORMAT=
  eval "$(direnv hook zsh)"
fi

[ -f ~/.aliases ] && source ~/.aliases

[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# This will not run
if [[ '' ]]; then
# FullStory Specific!
# We don't actually want to run this here. These are in .profile and .zshrc.local,
# but fsdev forces these lines into this file.
# They MUST NOT have prefixed whitespace, or fsdev will add them again.
if [ -e /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; else eval "$(/opt/homebrew/bin/brew shellenv)"; fi
source /Users/andymiller/.fsprofile
eval "$(direnv hook zsh)"
fi
