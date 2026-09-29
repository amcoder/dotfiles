---
paths:
  - "themes/**"
  - ".local/bin/theme"
  - ".local/share/themes/**"
  - ".config/tmux/**"
  - ".config/btop/**"
  - ".config/environment.d/20-qt.conf"
  - ".config/qt5ct/**"
  - ".config/qt6ct/**"
---

# Themes

Working rules for `.local/bin/theme` and everything it renders, including the
Qt/KDE side. How each was established is in `.claude/themes-reference.md`; read
the relevant part there before changing a mechanism described here.

## How it fits together

- One palette per theme in `themes/*.json`, templates in `themes/templates/`,
  rendered by `theme`. Selection lives in `$XDG_STATE_HOME/theme/current`, and
  output lands in `~/.config`, so switching never dirties the repo. Commands:
  `theme list|current|set <name>|apply`.
- Templates use Catppuccin's 26 colour names as generic roles. Placeholders:
  `{{role}}` (`#rrggbb`), `{{role_raw}}` (bare hex, swaylock and Qt ARGB),
  `{{role_rgb}}` (`r,g,b`, kdeglobals).
- Adding a theme is one JSON file. Adding an app is a template plus a `TARGETS`
  entry. A template is the palette, never the layout: keep design in a tracked
  file that references the generated colours (tmux's `theme.tmux` +
  `statusline.conf`, btop's `themes/dotfiles.theme` + `btop.conf`).
- Generated files go where each app already looks. Where an app has no include
  mechanism the whole file is generated and untracked, and the generator unlinks
  a leftover repo symlink before writing.
- Each theme's `"appearance": "dark" | "light"` is applied as real desktop state
  (`color-scheme` gsetting, `gtk-application-prefer-dark-theme`) even under
  `--no-reload`.

## GTK

- GTK3's palette is a generated GTK theme at `$XDG_DATA_HOME/themes/dotfiles`
  (`@import` of the base theme, then our `@define-color`s), not
  `~/.config/gtk-3.0/gtk.css`. That file must not carry the palette.
- The `gtk-theme` bounce that makes GTK re-read it must pass through a theme of
  the **same** appearance (`Adwaita-dark` for dark).
- `gtkTheme` must name an existing theme directory exactly (case-sensitive:
  `adw-gtk3-dark`). A wrong name silently loses the palette while keeping the
  widgets; `theme` warns on stderr and nothing else shows it.
- adw-gtk3 is vendored at `.local/share/themes/adw-gtk3{,-dark}` (upstream v6.5,
  `index.theme` and `gtk-3.0/` only). Update by re-extracting those parts and
  re-running `./install`.
- GTK4/libadwaita reads only `~/.config/gtk-4.0/gtk.css`, and GTK4 apps need a
  restart.

## Live reload per app

- **nvim**: `init.lua` watches the `lua/` **directory** with `vim.uv` fs_event,
  `vim.schedule()`s the callback, `dofile`s `theme.lua`, and compares against
  `vim.g.colors_name`. Every colorscheme plugin is a start plugin.
- **zsh**: the `theme-reload` precmd hook watches `theme.zsh`'s mtime with
  `zstat` and re-sources it, `FZF_DEFAULT_OPTS` and `$P10K_CONFIG`.
  `THEME_P10K_EDGE` must equal the terminal background. `theme apply` deletes
  the p10k instant-prompt cache.
- **tmux**: `statusline.conf` sets options with `-gF`, so a switch has to
  re-source `tmux.conf`. Keep the session module's prefix colour a render-time
  `#{E:@thm_red}`: tmux cannot parse a raw `#rrggbb` inside `#{?...}`.
- **btop**: `color_theme = "dotfiles"` (bare name, portable). btop writes
  `btop.conf` in place through the symlink and only when something changed. It
  does not re-read the theme while running, so it needs a restart. Verify by
  rendering under a sized pty and grepping for the background as an SGR triplet,
  not by reading the config.
- **quickshell** reads `palette.json` live (see `rules/quickshell.md`).

## Qt/KDE

- `QT_QPA_PLATFORMTHEME=kde` (in `environment.d/20-qt.conf`, not `uwsm/env`) is
  what makes Qt apps read `kdeglobals` at all. It lands at the next login.
- `kdeglobals` is generated from `kdeglobals.tmpl`. KDE Frameworks apps ignore
  qt5ct/qt6ct entirely; those configs remain only for Qt5 apps like VLC.
- Running Qt apps repaint only if `notify_kde` sends **both** the kconfig
  `ConfigChanged` and the legacy `KGlobalSettings.notifyChange` (0, 2, 4).
- KDE apps are single-instance: `killall dolphin` before testing a change.
- Qt and GTK both use Cantarell 11 and DejaVu Sans Mono 11. The GTK side lives
  in gsettings, so change both together. Compare fonts by cap height, not point
  size.
