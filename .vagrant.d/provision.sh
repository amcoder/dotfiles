#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install tmux vim zsh git-core
su -c "sudo chsh -s `which zsh` vagrant" vagrant
