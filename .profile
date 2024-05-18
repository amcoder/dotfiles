# ~/.profile
#
# Executed upon login. The intention is that this file is sourced by whatever
# mechanism is used to log in, whether that is a login shell, or a graphical
# environment. This must stay POSIX compliant.

[ -f /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
[ -f /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
[ -d /usr/local/go/bin ] && PATH="$PATH:/usr/local/go/bin"

[ -d "$HOME/bin" ] && PATH="$HOME/bin:$PATH"
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.jenv/bin" ] && PATH="$HOME/.jenv/bin:$PATH"
[ -d "$HOME/go/bin" ] && PATH="$HOME/go/bin:$PATH"
[ -d "$HOME/.local/go/bin" ] && PATH="$HOME/.local/go/bin:$PATH"
[ -d "$HOME/.local/share/fzf/bin" ] && PATH="$HOME/.local/share/fzf/bin:$PATH"

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export PATH

[ -z "$MANPATH" ] && MANPATH=$(manpath)
[ -d "$HOME/.local/share/man" ] && MANPATH="$HOME/.local/share/man:$MANPATH"
[ -d "$HOME/.local/man" ] && MANPATH="$HOME/.local/man:$MANPATH"

export MANPATH

export PAGER=less
export MANPAGER=less
if command -v nvim > /dev/null; then
  export EDITOR=nvim
  export VISUAL=nvim
  export MANPAGER='nvim +Man!'
elif command -v vim > /dev/null; then
  export EDITOR=vim
  export VISUAL=vim
else
  export EDITOR=vi
  export VISUAL=vi
fi

export MBOX=~/.mbox

trap logout HUP

[ -f "$HOME/.profile.local" ] && . "$HOME/.profile.local"

export _PROFILE_LOADED=$(( ${_PROFILE_LOADED:-0} + 1 ))
