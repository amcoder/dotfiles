#!/bin/sh

chmod 600 .config/.ssh/*
rm .bashrc
rm .bash_logout
rm .profile
rm .gitconfig
rm .gitignore_global
rm -rf .ssh
rm -rf .vim
rm .vimrc

ln -s .config/.bashrc
ln -s .config/.bash_logout
ln -s .config/.profile
ln -s .config/.gitconfig
ln -s .config/.gitignore_global
ln -s .config/.ssh
ln -s .config/.vim
ln -s .config/.vimrc
