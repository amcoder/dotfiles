# Setup fzf
# ---------
if [[ ! "$PATH" == */home/amcoder/.local/share/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/amcoder/.local/share/fzf/bin"
fi

source <(fzf --zsh)
