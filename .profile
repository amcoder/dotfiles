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

export MBOX="$XDG_DATA_HOME/mail/mbox"

export DOCKER_CONFIG="$XDG_CONFIG_HOME"/docker

export CARGO_HOME="$XDG_DATA_HOME"/cargo
export RUSTUP_HOME="$XDG_DATA_HOME"/rustup

export NPM_CONFIG_USERCONFIG=$XDG_CONFIG_HOME/npm/config
export NPM_CONFIG_CACHE=$XDG_CACHE_HOME/npm
export NVM_DIR="$XDG_DATA_HOME/nvm"

export NUGET_PACKAGES="$XDG_CACHE_HOME"/NuGetPackages
export OMNISHARPHOME="$XDG_CONFIG_HOME/omnisharp"

export WGETRC="$XDG_CONFIG_HOME/wgetrc"

export GTK_RC_FILES="$XDG_CONFIG_HOME"/gtk-1.0/gtkrc
export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0/gtkrc":"$XDG_CONFIG_HOME/gtk-2.0/gtkrc.mine"

export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
export PYTHONPYCACHEPREFIX="$XDG_CACHE_HOME/python"

[ -f /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
[ -f /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
[ -d /usr/local/go/bin ] && PATH="$PATH:/usr/local/go/bin"

# Add local bin directories to PATH if they exist.
while read -r p; do
  [ -d "$p" ] && PATH="$p:$PATH"
done <<EOF
$HOME/bin
$HOME/.local/bin
$XDG_DATA_HOME/fzf/bin
$XDG_DATA_HOME/go/bin
$CARGO_HOME/bin
$XDG_DATA_HOME/Rider/bin
$XDG_DATA_HOME/DataGrip/bin
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

# Add kubeconfigs to KUBECONFIG
while read -r p; do
  [ -d "$p" ] && KUBECONFIG="$p:$KUBECONFIG"
done <<EOF
$HOME/.kube/config
$HOME/.kube/homelab.config
$HOME/.kube/lytx.config
EOF

export KUBECONFIG

trap logout HUP

[ -f "$HOME/.profile.local" ] && . "$HOME/.profile.local"
