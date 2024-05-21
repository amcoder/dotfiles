# ~/.profile
#
# Executed upon login. The intention is that this file is sourced by whatever
# mechanism is used to log in, whether that is a login shell, or a graphical
# environment. This must stay POSIX compliant.

export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
export XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
export XDG_BIN_HOME=${XDG_BIN_HOME:-$HOME/.local/bin}

[ -f /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
[ -f /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
[ -d /usr/local/go/bin ] && PATH="$PATH:/usr/local/go/bin"

# Add local bin directories to PATH if they exist.
while read -r p; do
  [ -d "$p" ] && PATH="$p:$PATH"
done <<EOF
$HOME/bin
$HOME/.local/bin
$HOME/go/bin
$HOME/.local/go/bin
$HOME/.local/share/fzf/bin
$HOME/.cargo/bin
EOF

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

export MBOX="$XDG_DATA_HOME/mail/mbox"

trap logout HUP

[ -f "$HOME/.profile.local" ] && . "$HOME/.profile.local"

export _PROFILE_LOADED=$(( ${_PROFILE_LOADED:-0} + 1 ))
