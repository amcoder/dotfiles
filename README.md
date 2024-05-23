# dotfiles

## Installation

```sh
git clone git@github.com:amcoder/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install
```

## Themes

### Theme files

How do I make these configurable?

- GTK: .config/gtk-{3,4}.0
  - .themes
  - Gradience?
- QT: .config/qt5ct
- Sway: .config/sway (colors)
  - .config/sway/wallpaper
- Terminal: .config/alacritty/colors.yml
- Neovim: .config/nvim/lua/plugins/style
- zsh: .config/zsh/p10k.zsh
  - zsh-syntax-highlighting

### Links to themes

- [Nord](https://www.nordtheme.com/ports)
- [Catpuccin](https://github.com/catppuccin/catppuccin)
- [Rosé Pine](https://rosepinetheme.com/themes/)
- [Dracula](https://draculatheme.com/)
- [Everblush](https://github.com/Everblush)
- [Ayu](https://github.com/Shatur/neovim-ayu)
- [Base16](https://github.com/chriskempson/base16)

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
