alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias less='less -R'
alias more='less'

# Aliases for ls
if [ $TERM != "linux" ] && command -v eza &> /dev/null; then
  alias ls='eza --icons --classify'
  alias lst='eza --icons --classify --tree --level=2'
  alias la='eza --icons --classify --all'
  alias lat='eza --icons --classify --all --tree --level=2'
  alias ll='eza --icons --classify --long --group --header --links --git'
  alias llt='eza --icons --classify --long --group --header --links --git --tree --level=2'
  alias lla='eza --icons --classify --long --group --header --links --git --all'
  alias llat='eza --icons --classify --long --group --header --links --git --tree --level=2 --all'
  alias tree='eza --icons --classify --tree'
else
  alias ls='ls --color'
  alias la='ls -A --color'
  alias ll='ls -lh --color'
  alias lla='ls -lAh --color'
fi

if ! command -v fd &> /dev/null && command -v fdfind &> /dev/null; then
  alias fd='fdfind'
fi

# tmux
tms() {
  tmux new-session -As ${1:-default}
}

# term color map
colormap() {
  for i in {0..15}; do print -Pn "%K{$i}      %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%8)):#7}:+$'\n'}; done
}

if command -v nvim &> /dev/null; then
  alias vim='nvim'
  alias vi='nvim'
elif command -v vim &> /dev/null; then
  alias vi='vim'
fi

if command -v just &> /dev/null; then
  alias j='just'
  alias jb='just build'
  alias jt='just test'
  alias jtw='just test-watch'
  alias jr='just run'
  alias jrw='just run-watch'
  alias jc='just clean'
fi

# Named directories
if [ -d "$HOME/projects/transact" ]; then
  for dir in $HOME/projects/transact/*/; do
    hash -d "${${dir:t}##(bb-ea-|eaevo-(ui-|api-|))}"="${dir%/}"
  done
fi

[ -f "$ZDOTDIR/aliases.local.zsh" ] && source "$ZDOTDIR/aliases.local.zsh"
