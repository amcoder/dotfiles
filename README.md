# dotfiles

## Installation

```sh
git clone git@github.com:amcoder/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install
```

`install` symlinks every tracked file into `$HOME` and then runs `dot-prune`,
which deletes links under the managed roots that point into the repo but no
longer resolve — renaming a file here otherwise leaves a dangling link behind.

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
| `sway/theme.conf` | sway colors + the solid-colour desktop backstop | `swaymsg client.*` / `output bg` |
| `quickshell/palette.json` | status bar, notifications, launcher, switcher, session menu, wallpaper | live, file is watched |
| `alacritty/theme.toml` | terminal | live |
| `gtk-{3,4}.0/gtk{,-dark}.css` | GTK apps | gsettings nudge |
| `gtk-{3,4}.0/settings.ini` | GTK theme + dark/light preference | app restart |
| `kdeglobals` | Qt/KDE apps | app restart |
| `qt{5,6}ct/colors/theme.conf` | Qt5 apps (VLC) | app restart |
| `swaylock/config` | emergency lock screen (the normal one is quickshell) | next lock |
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

## Session services

The desktop shell runs as a systemd user service, not as a sway `exec`. The sway
config starts `sway-session.target`, which `BindsTo` `graphical-session.target`
and `PropagatesStopTo` it, and so pulls in `quickshell.service`, `poweralertd.service` and
`wayland-pipewire-idle-inhibit.service` — and takes them down again on logout.

```sh
systemctl --user restart quickshell     # reload the bar; sway is untouched
journalctl --user -u quickshell -f      # the shell's own log
systemctl --user status sway-session.target
```

`swaymsg reload` no longer restarts the bar, and a QML edit that kills the shell
is recovered by `Restart=always` (capped at `StartLimitBurst=5`). Every escape
hatch — `$mod+Return`, `$mod+Shift+q`, workspace switching, lock — is a sway
keybind and keeps working with quickshell stopped. The lock screen is a
*separate* unit for the same reason: if the shell held the session lock and
crashed, sway would keep the session locked with nothing to type into. The launcher, window switcher
and session menu do not: they are quickshell surfaces reached over IPC, so with
the shell down `$mod+Return` is the way back to a terminal.

The user manager never sources `~/.profile`, so the XDG base directories and
`~/.local/bin` come from `.config/environment.d/10-xdg.conf`; without them
`theme` and the `sway-*` scripts are unreachable from any user unit.

`./install` runs `systemctl --user daemon-reload` and enables the unit. Editing
an existing unit needs a `daemon-reload` of its own.

## Lock screen and idle

`lock` locks the session: it starts `quickshell-lock.service` and waits for the
lock surfaces to map before returning, so a suspend cannot race a half-drawn
lock. swayidle is only an adapter for logind's Lock/Unlock/PrepareForSleep
signals now — the dim (240s) and lock (300s) timeouts live in the shell, in
`quickshell/services/IdleService.qml`.

```sh
lock                                    # what $mod+Escape and before-sleep reach
QS_LOCK_DEMO=1 quickshell -p ~/.config/quickshell/lock.qml   # same UI, Escape closes it
```

Work on the lock screen in `QS_LOCK_DEMO=1`, never by locking for real.

**If a lock screen ever leaves you stuck**, switch to a VT with `Ctrl+Alt+F2`,
log in, and start a fresh lock client — sway accepts a replacement for an
abandoned lock, so this gives you a prompt you can type into:

```sh
XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user start quickshell-lock.service
```

Last resort, which ends the session and loses unsaved work:

```sh
SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock) swaymsg exit
```

If quickshell does not map within two seconds, `lock` falls back to
`swaylock -f`, which is why swaylock stays installed and themed.

## Login

The desktop logs in through [greetd](https://sr.ht/~kennylevinsen/greetd/) on
VT7, which runs a bare sway whose only job is to host
[gtkgreet](https://git.sr.ht/~kennylevinsen/gtkgreet). Choosing a session there
runs `uwsm start -- sway.desktop`, so the session is set up exactly as it was
when that command was typed by hand.

```sh
sudo apt install greetd gtkgreet sway
sudo ./system/install-greetd
```

`system/` holds root-owned configuration and sits outside the four paths
`install` symlinks into `$HOME`. These files are **copied, not linked**, so
re-run `sudo ./system/install-greetd` after editing anything under
`system/greetd/` — otherwise the change stays in the repo. The script also
validates the greeter's sway config, adds `_greetd` to `video` and `render`,
and enables `greetd.service`.

| File | What it is |
| --- | --- |
| `system/greetd/config.toml` | greetd itself: the VT, and the greeter command |
| `system/greetd/sway-config` | the compositor that hosts gtkgreet |
| `system/greetd/environments` | the sessions gtkgreet offers |
| `system/greetd/gtkgreet.css` | the login screen's appearance |

The stylesheet is hand-written and **not** generated by `theme` — `theme set`
changes the desktop and leaves the login screen alone, which is what keeps
`theme` from ever needing root. It is Catppuccin Macchiato, matching the
install-time default.

### Applying it, and getting back in

Restarting greetd ends the graphical session, so switch to a text console
first and do it from there — then you are already somewhere useful if the
greeter does not come up:

```sh
sudo systemctl restart greetd
```

`greetd.service` claims VT7 alone (`Conflicts=getty@tty7.service`) and
tty1–tty6 keep their gettys, so **Ctrl+Alt+F2** is always the way back in. From
there, `uwsm start default` still starts a session by hand exactly as before.

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

# Not exec'd -- the teardown below runs when sway exits. Output goes to the
# journal under the `sway` identifier.
systemd-cat --identifier=sway sway "$@"

# Without this quickshell outlives the compositor and Restart=always spins.
systemctl --user stop sway-session.target
```
