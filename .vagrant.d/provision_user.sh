#!/usr/bin/env zsh

ssh -o StrictHostKeyChecking=no git@github.com
git clone --recursive git@github.com:amcoder/dotfiles.git /home/vagrant/.dotfiles
export SHELL=`which zsh`
/home/vagrant/.dotfiles/install.sh
