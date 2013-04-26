#!/bin/sh

ignorefiles=". .. .DS_Store .git .gitignore .gitmodules"
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

echo "Ensuring security of files"
chmod 700 $scriptdir/.ssh
chmod 600 $scriptdir/.ssh/*

for file in .*
do
  if exclude $file; then
    echo "Skipping $file"
    continue
  fi
  echo "Setting up $file"
  if [ -e ~/$file ]; then
    if [ -L ~/$file ]; then
      echo "  ~/$file is symlinked. deleting"
      rm ~/$file
    else
      echo "  ~/$file exists. backing up to ~/$file.backup"
      rm -rf ~/$file
      mv ~/$file ~/$file.backup
    fi
  fi
  ln -s $scriptdir/$file ~/$file
done


# rm .bashrc
# rm .bash_logout
# rm .profile
# rm .gitconfig
# rm .gitignore_global
# rm -rf .ssh
# rm -rf .vim
# rm .vimrc
# 
# ln -s .config/.bashrc
# ln -s .config/.bash_logout
# ln -s .config/.profile
# ln -s .config/.gitconfig
# ln -s .config/.gitignore_global
# ln -s .config/.ssh
# ln -s .config/.vim
# ln -s .config/.vimrc
