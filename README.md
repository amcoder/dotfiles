# dotfiles

## Installation

```sh
git clone git@github.com:amcoder/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install
```

## Themes

One palette drives the whole desktop. Pick a theme from the bar's palette icon
or with `$mod+Ctrl+t`, or from a shell:

```sh
theme list
theme set nord
theme current
```

The selection is stored in `$XDG_STATE_HOME/theme/current`, on the machine
rather than in this repo, so switching themes leaves `git status` clean.

### How it works

`themes/<name>.json` holds a theme's colours, whether the desktop should be in
`"appearance": "dark"` or `"light"` mode, and its per-app choices (wallpaper,
GTK and icon themes, bat theme, nvim colorscheme). The appearance is applied as
a real system setting, so apps that follow the system dark/light preference —
Electron ones like the Claude desktop app read it through xdg-desktop-portal —
switch with the theme. `themes/templates/` holds one template
per app, written against a shared set of colour role names. `.local/bin/theme`
renders the templates into `~/.config` and then reloads what can be reloaded.
`./install` runs `theme apply` at the end, so a fresh machine comes up themed
(catppuccin-macchiato by default).

To add a theme, write one JSON file. To bring another app under theming, add a
template and list it in `TARGETS` in `.local/bin/theme`.

### Touchpoints

| Generated file | App | Picks the change up |
| --- | --- | --- |
| `sway/theme.conf` | sway colors + wallpaper | `swaymsg reload` |
| `quickshell/palette.json` | status bar | live, file is watched |
| `alacritty/theme.toml` | terminal | live |
| `gtk-{3,4}.0/gtk{,-dark}.css` | GTK apps | gsettings nudge |
| `gtk-{3,4}.0/settings.ini` | GTK theme + dark/light preference | app restart |
| `kdeglobals` | Qt/KDE apps | app restart |
| `qt{5,6}ct/colors/theme.conf` | Qt5 apps (VLC) | app restart |
| `dunst/dunstrc.d/90-theme.conf` | notifications | `dunstctl reload` |
| `wofi/style.css` | launcher | next launch |
| `swaylock/config` | lock screen | next lock |
| `tmux/theme.tmux` | tmux palette (layout is in the tracked `tmux/statusline.conf`) | `tmux source-file` |
| `zsh/theme.zsh` | fzf, bat, p10k | new shell |
| `nvim/lua/theme.lua` | Neovim | restart |

VS Code is not covered — it has no include mechanism and its `settings.json`
holds unrelated settings, so switch its theme in the app.

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
