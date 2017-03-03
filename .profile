# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
  # include .bashrc if it exists
  if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
  fi
fi

# set PATH so it local bin if it exists
if [ -d "/usr/local/bin" ] ; then
  PATH="/usr/local/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
  PATH="$HOME/bin:$PATH"
fi

#Set PATH to include the rvm binary
if [ -d $HOME/.rvm/bin ]; then
  PATH=$HOME/.rvm/bin:$PATH # Add RVM to PATH for scripting
fi

#Set PATH to include the node binaries
if [ -d /usr/local/share/npm/bin ]; then
  PATH=/usr/local/share/npm/bin:$PATH # Add node to PATH for scripting

# Set the editor to vi
export EDITOR=vi

# Fix for some ssh servers
export LC_CTYPE="en_US.UTF-8"

# Set up nova client
export OS_USERNAME=amcoder
export NOVA_RAX_AUTH=1
export OS_AUTH_URL=https://identity.api.rackspacecloud.com/v2.0/
export NOVA_VERSION=2
export NOVA_SERVICE_NAME=cloudServersOpenStack
export OS_REGION_NAME=ORD
export OS_TENANT_NAME=629265

# start pageant ssh-agent on cygwin
if [ -z "$SSH_AUTH_SOCK" -a -x /usr/bin/ssh-pageant ]; then
  eval $(/usr/bin/ssh-pageant -q)
fi

# Load rvm
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

trap logout HUP


export PATH="$HOME/.cargo/bin:$PATH"
