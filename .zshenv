# This is only here to set the ZDOTDIR environment variable to the correct location.
# See .config/zsh for the real configuration.

export ZDOTDIR="${XDG_CONFIG_DIR:-$HOME/.config}/zsh"

source $ZDOTDIR/.zshenv
