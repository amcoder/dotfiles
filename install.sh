#!/usr/bin/env bash

ignorefiles=". .. .DS_Store .git .gitignore .gitmodules .config .local"
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir

exclude() {
  for f in $ignorefiles
  do
    if [ $f = $1 ]; then
      return 0
    fi
  done
  return 1
}

mkdir -p ~/.config
mkdir -p ~/.local/bin

for file in .* .local/bin/* .config/*
do
  if exclude $file; then
    echo "Skipping $file"
    continue
  fi
  echo "Setting up $file"
  if [ -e ~/$file ] && [ ! -L ~/$file ]; then
    backup="$file.backup.$(date +%s)"
    echo "  ~/$file exists. backing up to ~/$backup"
    mv ~/$file ~/$backup
  fi
  rm -rf ~/$file
  ln -s $scriptdir/$file ~/$file
done

zsh_location=`which zsh`
if [ $zsh_location != "" ]; then
  if [ $SHELL != $zsh_location ]; then
    echo "\033[0;34mTime to change your default shell to zsh!\033[0m"
    chsh -s $zsh_location

    /usr/bin/env zsh
    source ~/.zshrc
  else
    echo "Already using ZSH"
  fi
else
  echo "ZSH not installed. Skipping ZSH setup"
fi
