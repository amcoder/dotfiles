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

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable bi-weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment to change how often before auto-updates occur? (in days)
# export UPDATE_ZSH_DAYS=13

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want to disable command autocorrection
DISABLE_CORRECTION="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Uncomment following line if you want to disable marking untracked files under
# VCS as dirty. This makes repository status check for large repositories much,
# much faster.
#DISABLE_UNTRACKED_FILES_DIRTY="true"

# enable agent forwarding
zstyle :omz:plugins:ssh-agent agent-forwarding on

# Pass unmatched extended globs to the command
unsetopt nomatch

# set PATH so it local bin if it exists
if [ -d "/usr/local/bin" ] ; then
  PATH="/usr/local/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
  PATH="$HOME/bin:$PATH"
fi

#Set PATH to include the node binaries
if [ -d /usr/local/share/npm/bin ]; then
  PATH=/usr/local/share/npm/bin:$PATH
fi

#Set PATH to include the rvm binary
if [ -d $HOME/.rvm/bin ]; then
  PATH="$PATH:$HOME/.rvm/bin"
fi

# Add cabal to the path
if [ -d $HOME/.cabal/bin ]; then
  PATH=$HOME/.cabal/bin:$PATH
fi

if [ -d $HOME/.cargo/bin ]; then
  PATH=$HOME/.cargo/bin:$PATH
fi

if [ -d $HOME/.jenv/bin ]; then
  PATH=$HOME/.jenv/bin:$PATH
fi

export PATH

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

# Customize to your needs...

# Aliases
alias ll='ls -l'
alias la='ls -A'
alias lla='la -al'
alias l='ls -CF'

# Set up color output on mac
if [ `uname` = "Darwin" ]; then
  export LS_COLORS='exfxcxdxbxegedabagacad'
  export LSCOLORS=$LS_COLORS
fi

# enable color support of ls and also add handy aliases on GNU machones
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# Set the editor to vi
export EDITOR=vi

# Fix for some ssh servers
export LC_CTYPE="en_US.UTF-8"

if [ -d /usr/local/opt/chruby ]; then
  source /usr/local/opt/chruby/share/chruby/chruby.sh
  source /usr/local/opt/chruby/share/chruby/auto.sh
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

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

if [ -f ~/.zshrc.local ]; then
  source ~/.zshrc.local
fi

