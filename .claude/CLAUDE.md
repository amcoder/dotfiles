# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal dotfiles for a Linux (Debian, Sway/Wayland) and macOS environment. The repo mirrors `$HOME`: `.config/`, `.local/bin/`, `.profile`, and `.zshenv` are symlinked into the home directory, so edits to files here take effect immediately in the live environment — no build or deploy step.

## Commands

- `./install` — symlink all tracked files into `$HOME` (backs up any existing non-symlink files). Must be re-run after adding a **new** file to the repo so its symlink gets created; editing existing files needs nothing.
- `./install --deps` — also install packages (Homebrew bundle from `Brewfile` on macOS, `apt` on Debian/Ubuntu).
- `dot-add <file>` — zsh function (defined in `.config/zsh/dot.zsh`) that moves an existing file from `$HOME` into the repo, symlinks it back, and commits it. Prefer this when bringing a new config file under management.

There are no tests or linters for the repo as a whole. Neovim Lua is formatted with stylua per `.config/nvim/.stylua.toml` (2-space indent, prefer single quotes).

## Structure

- **zsh** (`.config/zsh/`): the root `.zshenv` only sets `ZDOTDIR` to `.config/zsh`; all real config lives there. Plugins are managed by zinit (auto-cloned on first shell start). Load order is documented at the top of `.zshrc`. `install` writes a generated `dotfiles-dir.zsh` (untracked) into `ZDOTDIR` exporting `DOTFILES_DIR`.
- **Neovim** (`.config/nvim/`): kickstart.nvim-style single `init.lua` for options/keymaps, with lazy.nvim loading one plugin spec file per concern from `lua/plugins/`. Add new plugins as a new file in that directory. `lazy-lock.json` pins plugin versions.
- **Themes**: apps carry multiple theme variants side by side (e.g. `alacritty/colors-nord.toml` vs `colors-catppuccin-macchiato.toml`, `sway/nord.conf` vs `catppuccin.conf`, tmux, swaylock, gtk-4.0 likewise). Switching themes is manual — the active config includes/points at one variant. The README lists all theme touchpoints; keep variants in sync when changing one.
- **Scripts** (`.local/bin/`): standalone helper scripts, mostly for Sway/Wayland (brightness, volume, window switcher, etc.).
- **Quickshell** (`.config/quickshell/`): the Wayland status bar, built with [Quickshell](https://quickshell.outfoxxed.me/) (QML). It replaces swaybar/i3blocks; sway starts it via `exec_always` and declares no bar of its own. `shell.qml` is the entry point, defining a `PanelWindow` top bar per screen (`Bar.qml`). Colors live in `Theme.qml`, which hardcodes Catppuccin Macchiato and must be kept in sync with `.config/sway/catppuccin.conf`. Run with `quickshell` to test changes live; QML edits hot-reload — but a **new** file (a new singleton especially) needs a full restart, since hot-reload will not register it and the bar dies with "X is not defined".

  Icons are vendored Phosphor SVGs in `icons/`, drawn by `Icon.qml` as `Icon { name: "bell"; color: Theme.yellow }`. `Icons.qml` reads the SVG through a `FileView` and caches it; `Icon.qml` swaps the file's `#ffffff` placeholder fill for the requested colour and hands the result to `Image` as a `data:` URI. Recolouring has to happen in the SVG markup — tinting the rendered image with `MultiEffect` (either `colorization` or an alpha mask) blows out thin strokes at bar sizes until enclosed shapes fill in solid. To add an icon, drop the file from [Phosphor](https://phosphoricons.com/) (regular weight) into `icons/`, replace its `fill="currentColor"` with `fill="#ffffff"`, and re-run `./install`.

  Workspace icons are named by sway: each `set $wsN` in `.config/sway/config` carries a `<span foreground='...'>icon-name</span>`, and `Workspaces.qml` parses the span for the colour and the icon name. Sway only applies renamed workspaces to newly created ones, so after editing those lines, existing workspaces keep their old names until `swaymsg rename workspace` is run or they are recreated.

  The bar is always visible and reserves its own height via `ExclusionMode.Auto`, so windows start below it. `Theme.barBorder` draws along the bar's bottom edge, against the windows rather than the screen edge.
- **Sway**: expects a system-level `/usr/local/bin/sway-run` launcher (documented in README, not tracked here) that exports Wayland env vars and sources `.config/sway/profile`.
