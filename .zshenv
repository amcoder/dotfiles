# This is loaded first for all zsh instances
# Load order:
# - .zshenv
# - .zprofile (login only)
# - .zshrc (interactive only)
# - .zlogin (login only)
# - .zlogout (logout only)

typeset -aU path
typeset -U PATH

[ -d "/usr/local/bin" ] && PATH="/usr/local/bin:$PATH"

if [ -d /opt/homebrew/bin ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

[ -d /usr/local/go/bin ] && PATH=$PATH:/usr/local/go/bin

[ -d "$HOME/bin" ] && PATH="$HOME/bin:$PATH"
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d $HOME/.jenv/bin ] && PATH=$HOME/.jenv/bin:$PATH
[ -d $HOME/go/bin ] && PATH=$PATH:$HOME/go/bin
[ -d $HOME/.cargo ] && source "$HOME/.cargo/env"

export PATH
#
# Set the editor to vi
export EDITOR=vi
export VISUAL=vi
export PAGER=less
if command -v nvim &> /dev/null; then
  export MANPAGER='nvim +Man!'
else
  export MANPAGER=less
fi

# Fix for some ssh servers
export LANG="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

[ -f ~/.zshenv.local ] && source ~/.zshenv.local
