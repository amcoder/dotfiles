# dotfiles

## Installation

```sh
git clone git@github.com:amcoder/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install
```

## Sway run

This will handle setting up the environment for sway.

/usr/local/bin/sway-run

```sh
#!/bin/sh

# Session
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=sway
export XDG_CURRENT_DESKTOP=sway

# Wayland stuff
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
export ADW_DISABLE_PORTAL=1
export ELECTRON_OZONE_PLATFORM_HINT=auto

if [ -f ~/.config/sway/profile ]; then
    . ~/.config/sway/profile
fi

# exec sway "$@"

#
# If you use systemd and want sway output to go to the journal, use this
# instead of the `exec sway "$@"` above:
#
exec systemd-cat --identifier=sway sway "$@"
```
