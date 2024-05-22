[ -f "$ZDOTDIR/dotfiles-dir.zsh" ] && source "$ZDOTDIR/dotfiles-dir.zsh"
[ -d "$DOTFILES_DIR" ] || return;

dot-add() {
  local files=("$@")
  local gitchanges=

  for file in "${files[@]}"; do
    [ ! -f "$file" ] && echo "File not found at $file" && continue

    local relfile=$(realpath -s --relative-to=$HOME "$file")
    local dotfile="$DOTFILES_DIR/$relfile"
    echo "Adding $file to $dotfile"
    mkdir -p "$(dirname $dotfile)"
    mv "$file" "$dotfile"
    ln -s "$dotfile" "$file"
    git -C "$DOTFILES_DIR" add "$dotfile"
    gitchanges=1
  done
  [ $gitchanges ] && git -C "$DOTFILES_DIR" commit -m "Add files: ${(F)files}"
}
