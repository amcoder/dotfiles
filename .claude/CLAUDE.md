# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What this is

Personal dotfiles for a Linux (Debian, Sway/Wayland) and macOS environment. The
repo mirrors `$HOME`: `.config/`, `.local/bin/`, `.profile`, and `.zshenv` are
symlinked into the home directory, so edits to files here take effect
immediately in the live environment — no build or deploy step. `claude/` is
linked in too, to a destination that is not its own path (see Claude Code).

## Commands

- `./install` — symlink all tracked files into `$HOME` (backs up any existing
  non-symlink files). Must be re-run after adding a **new** file to the repo so
  its symlink gets created; editing existing files needs nothing. A second loop
  links `claude/<path>` to `~/.claude/<path>`, which the mirroring loop cannot
  do.
- `./install --deps` — also install dependencies, **before** the symlink pass
  rather than after it: a Homebrew bundle from `Brewfile` on macOS, `apt` on
  Debian/Ubuntu, plus nvm and rustup on both. The ordering is load-bearing —
  everything after the symlink loop (enabling the quickshell units,
  `theme apply`) needs those binaries to already exist, so on a fresh machine a
  `--deps` run that installed last would enable a unit whose binary was still
  missing. Node and Rust come from nvm and rustup rather than apt because each
  owns its own toolchain and `.config/zsh/nvm.zsh` switches node per `.nvmrc`;
  an apt copy would sit in front of whatever those selected. Both installers
  append PATH lines to a shell profile by default, which here means editing
  `~/.profile` — **a symlink into this repo** — so both are given their own
  opt-out (`PROFILE=/dev/null` for nvm, `--no-modify-path` for rustup). nvm
  additionally refuses to create `$NVM_DIR` anywhere but its own default
  `~/.nvm`, and this repo puts it under `XDG_DATA_HOME`, so the directory has to
  exist first.
- `dot-add <file>` — zsh function (defined in `.config/zsh/dot.zsh`) that moves
  an existing file from `$HOME` into the repo, symlinks it back, and commits it.
  Prefer this when bringing a new config file under management.
- `dot-prune` — deletes symlinks under the five managed roots (the four mirrored
  paths plus `~/.claude`) that point into the repo but no longer resolve.
  `install` runs it after linking, because `ln` never removes anything: renaming
  a tracked file leaves a dangling link in `$HOME`, and quickshell dies loading
  one. It only touches links whose target is inside `$DOTFILES_DIR`, so
  unrelated broken links elsewhere in `~/.config` are left alone.

There are no tests or linters for the repo as a whole. Neovim Lua is formatted
with stylua per `.config/nvim/.stylua.toml` (2-space indent, prefer single
quotes).

Markdown is formatted with prettier, wrapped at 80 columns: `.editorconfig` sets
the width and `.prettierrc` sets `proseWrap: always`. After creating or editing
any `.md` file in this repo, run `npx prettier@3 --write <file>` on it before
committing; prettier is not installed, so node comes from nvm
(`~/.local/share/nvm/versions/node/<version>/bin`). Tables, code blocks,
headings and long inline code spans cannot wrap and are left over 80.

## Structure

Most areas below are summarised here, with their working rules in
`.claude/rules/<area>.md` and the full notes behind those rules in
`.claude/<area>-reference.md`. A rule loads automatically when a file matching
its `paths:` is read, but not reliably: in testing about one read in four did
not load it. Before changing anything in an area, read its rule file unless its
contents are already in context.

- **zsh** (`.config/zsh/`): the root `.zshenv` only sets `ZDOTDIR` to
  `.config/zsh`; all real config lives there. Plugins are managed by zinit
  (auto-cloned on first shell start). Load order is documented at the top of
  `.zshrc`. `install` writes a generated `dotfiles-dir.zsh` (untracked) into
  `ZDOTDIR` exporting `DOTFILES_DIR`.
- **Neovim** (`.config/nvim/`): kickstart.nvim-style single `init.lua` for
  options/keymaps, with lazy.nvim loading one plugin spec file per concern from
  `lua/plugins/`. Add new plugins as a new file in that directory.
  `lazy-lock.json` pins plugin versions. `init.lua` also holds the theme watcher
  that follows `theme set` live (see Themes).
- **Claude Code** (`claude/`, repo root — linked into `~/.claude`, not
  mirrored): Claude Code keeps its config directory at `~/.claude`, which cannot
  be one of the four mirrored roots, because the repo's own `.claude/` is _this
  project's_ instructions — mirroring it into `$HOME` would lay this file over
  the user-level `CLAUDE.md`. So the home-level config lives in `claude/` and
  `install` links it file by file with a second loop mapping `claude/<path>` to
  `~/.claude/<path>`; `dot-prune` gained `~/.claude` as a fifth root. Only the
  four things that are configuration are tracked — `settings.json`,
  `keybindings.json`, `statusline-command.sh` and `rules/`. Everything else in
  that directory is state (`.credentials.json`, `.claude.json`, `history.jsonl`,
  `sessions/`, `projects/`, the plugin marketplace clones) and is simply not in
  the repo, which needs no `.gitignore` support because the repo only ever
  contains what was put in it.

  The global instructions are **split in two halves**. `~/.claude/CLAUDE.md` is
  untracked, machine-specific, and currently an empty file: the loader drops any
  entry whose trimmed content is empty, so an empty file costs no context while
  keeping the machine-local destination obvious. The shared half is
  `claude/rules/*.md`, linked into `~/.claude/rules/`. That directory is a
  first-class Claude Code feature rather than a trick — it is walked
  recursively, every `.md` under it loads, and the renderer labels an entry by
  its _type_ and not its filename, so a file in `~/.claude/rules/` reaches the
  context under exactly the same header as `CLAUDE.md` itself ("user's private
  global instructions for all projects"). Load order is managed → user
  `CLAUDE.md` → user rules → the project chain. One file per concern is the
  point: `comments.md`, `debugging.md`, `memory.md` and `instruction-scope.md`
  can each be edited, moved or made conditional without touching the others.

  A rules file may carry `paths:` frontmatter, which stops it being always-on
  and injects it only when a file matching those globs comes into play. **At
  user scope those globs match the touched path made relative to the cwd**,
  gitignore-style, and the matcher bails the moment that relative path escapes
  the cwd (`..`) or stays absolute. So a conditional rule keyed on anything
  under `$HOME` — `~/.claude/CLAUDE.md`, say — can essentially never fire,
  because no working session has that inside its cwd. `instruction-scope.md` is
  unconditional for that reason and for a second one: it has to be read _before_
  an instruction is written, while a conditional rule fires on file access,
  which is already too late. `paths:` is for per-language rules inside a project
  (`**/*.rs`), not for anything about the config directory itself.

  A **new** rules file needs `./install` before it loads, which is easy to miss
  here because editing an existing one needs nothing. The paths that appear in
  the loaded context are the **repo** paths
  (`~/.dotfiles/claude/rules/comments.md`) rather than the `~/.claude/rules/`
  links, because the loader canonicalises symlinks.

  Two things about `settings.json`, both measured rather than assumed. Claude
  Code rewrites it whenever a setting changes mid-session — theme, model, voice,
  plugin enablement — and it does so atomically **and** symlink-safely: it
  resolves the link first, creates `settings.json.tmp.<pid>.<hex>` in the
  _resolved_ directory, and renames that onto the target. Established by strace
  of a real write, and by four user-scope mutations against a scratch
  `CLAUDE_CONFIG_DIR` whose `settings.json` was a symlink — the link survived
  every one, and a 0600 target stayed 0600. Two consequences: the temp file
  lands in this repo, hence the `.gitignore` line, and the tracked file changes
  inode on every write, so anything holding it open keeps reading the old copy.
  The second thing is that the whole JSON object is rewritten with **no
  key-order guarantee**, so expect a reordering diff on the first write and
  ongoing churn from per-session toggles (`model`, `theme`, `voice`) — which are
  now shared across machines whether that was intended or not. Git records only
  the exec bit, so the file's 0600 here lands as 0644 on a fresh clone; it holds
  no secrets, the credentials being in the untracked `.credentials.json`.

  `CLAUDE_CONFIG_DIR` relocates the whole directory, and was considered for
  moving it under `.config` where the ordinary mirroring loop would cover it
  with no new machinery. Rejected: it moves the state and the credentials along
  with the config rather than separating them, and it has to be set in _every_
  context that starts Claude Code — the terminal CLI, the desktop app (which
  runs its own bundled build), any user unit — falling back silently to a fresh,
  logged-out `~/.claude` wherever it is missing.

- **Themes** (`themes/`, repo root, deliberately outside the four mirrored
  paths): one palette per theme (`themes/*.json`) plus `templates/`, from which
  `.local/bin/theme` renders every app's config. The selection lives in
  `$XDG_STATE_HOME/theme/current` and the output lands in `~/.config`, so
  switching never dirties the repo; `install` ends with `theme apply`,
  defaulting to catppuccin-macchiato. Use `theme list`, `theme current`,
  `theme set <name>`, `theme apply`. Adding a theme is one JSON file; adding an
  app is a template plus a `TARGETS` entry. zsh, nvim, quickshell, GTK3 and Qt
  apps follow a switch live; GTK4 apps and btop need a restart. Qt apps are
  themed through `kdeglobals`, which is read only because
  `QT_QPA_PLATFORMTHEME=kde` is set in `.config/environment.d/20-qt.conf`.
  Working rules are in `.claude/rules/themes.md` (loads for `themes/`, `theme`,
  the vendored adw-gtk3, tmux, btop and Qt files) and the full notes in
  `.claude/themes-reference.md`.
- **Fonts** (`.local/share/fonts/`): SauceCodePro Nerd Font is **vendored**, the
  same call as adw-gtk3, the Phosphor icons and `emoji.txt` —
  `.config/alacritty/font.toml` and `.config/Code/User/settings.json` both name
  it outright, and `vim.g.have_nerd_font` assumes its glyphs, so a fresh machine
  that has to download it comes up with the wrong font in every terminal. Like
  adw-gtk3 it needs no `install` support at all: `$XDG_DATA_HOME/fonts` is
  `~/.local/share/fonts`, already inside `.local`, so the ordinary symlink loop
  puts it in place.

  Two things make the arrangement work, both established by spike rather than
  assumed. **fontconfig recurses into subdirectories** of a declared font
  directory — verified with a face nested two levels deep under a `<dir>` that
  named only the parent — so the faces can live in their own `SauceCodePro/`
  subfolder instead of being strewn across `~/.local/share/fonts`. And
  **fontconfig registers symlinked font files**, which it has to, because
  `install` links rather than copies. No `fc-cache` call is needed either:
  fontconfig rescans a directory whose mtime has changed.

  Only the **base family** is vendored — 14 faces, 33MB. Upstream's
  `NerdFontMono` and `NerdFontPropo` variants (28 more faces, 68MB) are dropped
  for the reason adw-gtk3's `gtk-4.0/` is: nothing resolves them. Both consumers
  ask for the family `SauceCodePro Nerd Font`, which is the base. Every weight
  is kept rather than just the four that render today, so changing `font.toml`
  to another style does not need a trip back to the nerd-fonts release;
  alacritty remaps bold to Semibold (`font.bold.style`), so what it actually
  draws is Regular, Italic, SemiBold and SemiBoldItalic, while the VS Code
  terminal has no such remap and takes Bold. Adding a face means dropping the
  `.ttf` in and re-running `./install`. Note that a **copy** rather than a move
  when vendoring registers every face twice, since `install` then links the repo
  copy into the directory still holding the original.

- **Scripts** (`.local/bin/`): standalone helper scripts, mostly for
  Sway/Wayland (brightness, volume, output scaling, etc.).

- **Claude desktop** (`.local/bin/claude-desktop`): a wrapper that adds
  `--password-store=gnome-libsecret`, and it has to be a wrapper of that exact
  name. Chromium picks its secret backend from `XDG_CURRENT_DESKTOP`, and
  `sway:wlroots` lands on `basic_text`, which Electron reports as no encryption
  at all; the app then logs
  `[safeStorage] isEncryptionAvailable=false … session will not persist` and
  declines to save its OAuth tokens. The claude.ai cookie still survives
  (basic_text encrypts, just weakly), so relaunches looked fine, and every start
  re-derived the tokens from the cookie with a fresh `/authorize`, which the
  server refuses with `session_stale_relogin` once the cookie is about a day
  old: measured, the four re-login demands in the log were each the first start
  43h-3d after the previous login, and a start 23h after one was not. With the
  flag the encrypted `oauth:tokenCacheV2` lands in `config.json`.

  The flag cannot live in a desktop file: the app rewrites
  `~/.local/share/applications/com.anthropic.Claude.desktop` from the packaged
  entry on every start (`X-Claude-Generated=true`) and keeps only the first word
  of `Exec=` for its actions. Every path in (`Exec`, the actions, the
  `claude://` handler) resolves `claude-desktop` through `PATH`, where
  `~/.local/bin` precedes `/usr/bin` in sway's environment, so the wrapper
  catches all of them. The app reads the switch itself
  (`app.commandLine.getSwitchValue("password-store")`), so it is a path it
  anticipates.

- **File manager over D-Bus**
  (`.local/share/dbus-1/services/org.freedesktop.FileManager1.service`):
  Chrome's "Show in folder", and anything else that calls
  `org.freedesktop.FileManager1.ShowItems`, never reads `inode/directory` from
  `mimeapps.list`. It activates whatever owns that bus name, and three system
  service files claim it: nautilus, nemo and dolphin. Which of several
  same-named files in one directory wins is arbitrary, and it was nemo. The user
  service directory is searched before the system ones, so this file pins it to
  Nautilus. It only takes effect once the current owner exits, so after changing
  it kill that process (`busctl --user status org.freedesktop.FileManager1`
  names it) and reload the bus config.

  nemo is not something anyone asked for: it arrived with the whole Cinnamon
  desktop in the bootstrap `apt install`. `blueman` depends on the virtual
  `notification-daemon`, `network-manager-applet` on `polkit-1-auth-agent`, and
  nothing installed provided either one, since Quickshell is invisible to apt.
  `cinnamon` provides both, so apt satisfied the two of them with it. Purging it
  means installing some other provider of each first.

- **Output configuration** (`.local/bin/sway-outputs`, `sway-outputs.service`,
  and the display panel in quickshell): the sway config names no output.
  `sway-outputs` derives each panel's mode and scale from its EDID at login and
  on hotplug, and writes them to the generated, untracked
  `~/.config/sway/outputs.conf`, which sway `include`s so a reload reasserts
  them. A runtime change (`sway-scale`, `sway-toggle-aspect`, the display panel)
  therefore holds until the next `swaymsg reload`. **Never issue a
  `swaymsg output` that is not a real change**: every one is a modeset, lockup
  trigger #1 in `.claude/sway-lockup-investigation.md`. Key overrides by sway
  identifier, never by connector name, which is not stable. Working rules are in
  `.claude/rules/outputs.md` and the full notes in
  `.claude/outputs-reference.md`.
- **Quickshell** (`.config/quickshell/`): the whole desktop shell, written in
  QML with [Quickshell](https://quickshell.outfoxxed.me/): bar, notifications,
  launcher, window switcher and cycler, OSD, the
  audio/bluetooth/network/media/calendar/emoji panels, wallpaper, polkit agent
  and lock screen. It replaced swaybar, dunst, wofi, zenity, swaybg, pasystray,
  blueman-applet, playerctl, bemoji and polkit-kde. Its working rules are in
  `.claude/rules/quickshell.md`, which loads whenever a file under
  `.config/quickshell/` is opened, and the full notes behind them are in
  `.claude/quickshell-reference.md`. What matters from outside it:

  - It runs as `quickshell.service` under `sway-session.target`, not as a sway
    `exec`: restart it with `systemctl --user restart quickshell`, and its log
    is `journalctl --user -u quickshell`. `swaymsg reload` and theme switches do
    not restart it.
  - Sway reaches it only through `quickshell ipc call <target> <function>`. An
    IPC call exits 0 even when it did not land.
  - The lock screen is a separate process, `quickshell-lock.service`, started by
    `.local/bin/lock`. swayidle (`swayidle.service`) owns every idle timeout,
    and the shell only draws the dim.
  - nm-applet still runs (it is NetworkManager's secret agent) and
    blueman-applet is D-Bus activated as the BlueZ pairing agent: neither is a
    leftover. dunst is masked, not removed.
  - Adding, renaming or moving a file under it needs `./install`, and a dangling
    old link kills the shell at load.

- **Screencasting** (`.config/xdg-desktop-portal-wlr/config`,
  `.local/bin/screencast-chooser`, `services/ScreencastService.qml`,
  `modules/screencast/`): single-window sharing through xdg-desktop-portal-wlr,
  with a Quickshell thumbnail grid as its chooser (`chooser_cmd`). Two things
  worth knowing without opening those files: a share of a window that is not
  repainting sits on "Starting presentation" until it repaints, and a wedged
  portal is cleared with `systemctl --user restart xdg-desktop-portal-wlr`, not
  by restarting the browser. Working rules are in `.claude/rules/screencast.md`
  and the full notes in `.claude/screencast-reference.md`.

- **Screen recording** (`.local/bin/record-region`,
  `services/RecordingService.qml`, `modules/bar/Recording.qml`): `$mod+Ctrl+p`
  toggles a wf-recorder capture of a window, output or dragged region into
  `$(xdg-user-dir VIDEOS)/Recordings`, video only, at 60fps, with a red
  indicator left of the clock that stops it on click. Working rules are in
  `.claude/rules/recording.md` and the full notes in
  `.claude/recording-reference.md`.

- **Privacy indicators** (`.local/bin/camera-watch`,
  `services/PrivacyService.qml`, `modules/bar/Privacy.qml`, `modules/privacy/`):
  red webcam and microphone icons left of the clock while something captures,
  with a popup naming the processes. Notes in `.claude/rules/privacy.md`.
- **Idle inhibitors** (`services/IdleInhibitService.qml`,
  `modules/bar/IdleInhibit.qml`, `modules/idle/IdleInhibitPanel.qml`): a coffee
  cup left of the clock while a Wayland or logind idle inhibitor is holding the
  session awake, with a popup naming what. It is what makes the absence of any
  ceiling on inhibitor-held idle acceptable. Notes in
  `.claude/rules/idle-inhibitors.md`.
- **System monitor** (`.local/bin/sysmon-watch`,
  `services/SystemMonitorService.qml`, `modules/bar/SystemMonitor.qml`,
  `modules/sysmon/`): CPU and memory gauges in the bar opening a panel with
  history, cores and top processes. Notes in `.claude/rules/sysmon.md`.

- **Gaming** (`.config/gamemode.ini`, `.config/MangoHud/MangoHud.conf`,
  `.local/bin/hdr-run`, `.config/mpv/mpv.conf`): gamemode, a locally rebuilt
  MangoHud with NVML (held), ntsync, HDR and adaptive sync on demise. Steam
  launch options are `gamemoderun mangohud %command%`, or for HDR
  `hdr-run env PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_HDR=1 gamemoderun mangohud %command%`
  under Proton-GE. Two parts live in the sway config and so need knowing from
  outside these files: `output * adaptive_sync on` is deliberate, and
  **`seat * hide_cursor when-typing enable` must never come back**, because in
  sway 1.12 it breaks every locked-pointer game. HDR stays off at the desktop,
  since it lifts every screenshot, recording and screen share. Working rules are
  in `.claude/rules/gaming.md` and the full notes, benchmarks included, in
  `.claude/gaming-reference.md`.

- **Session services** (`.config/systemd/user/`): the shell runs under systemd,
  not as a sway `exec`. The sway config starts `sway-session.target`, which
  `BindsTo` + `PropagatesStopTo` `graphical-session.target` and so pulls in
  `quickshell.service` (`Restart=always`, `StartLimitBurst=5`),
  `swayidle.service` and `sway-outputs.service` plus the machine-local
  `poweralertd` and `wayland-pipewire-idle-inhibit` units already sitting in
  `graphical-session.target.wants/`. This keeps `swaymsg reload` and every theme
  switch out of the shell's lifecycle, and out of the DRM modeset path described
  in `.claude/sway-lockup-investigation.md`.

  The user manager never sources `~/.profile`, so the XDG base directories and
  `~/.local/bin` are declared in `.config/environment.d/10-xdg.conf` — without
  them `theme` and the `sway-*` scripts are unreachable from any user unit.
  `environment.d` rather than `Environment=` lines because it covers every unit
  at once, expands `${HOME}`/`${PATH}`, and applies on a plain `daemon-reload`.
  Files there merge by filename across all `environment.d` directories, so nix's
  unprefixed `nix-daemon.conf` sorts after `10-xdg.conf` and re-prepends its own
  paths. `quickshell.service` keeps only `QT_QPA_PLATFORM=wayland` and
  `QT_QPA_PLATFORMTHEME=kde`, which are about how the shell renders and used to
  be inherited from the `sway-run` launcher uwsm replaced.

  `wayland-pipewire-idle-inhibit.service` is tracked here too. Any unit added to
  this target needs `PartOf=graphical-session.target`, not just `WantedBy=` in
  `[Install]` — `WantedBy` starts it with the session but never stops it, and a
  `Restart=always` unit then spins against a dead compositor for the whole
  logout window.

  The sway side is one quoted `exec` that chains the environment import into the
  target start: `/etc/sway/config.d/50-systemd-user.conf` imports `SWAYSOCK` in
  a _separate_ `exec`, and sway launches execs asynchronously, so the target can
  otherwise start before the socket is in the manager's environment. The quotes
  are load-bearing — unquoted, sway parses `&&` (or a `;`) as the start of a
  second command and logs `Unknown/invalid command`.

  `PropagatesStopTo` is load-bearing and easy to lose: `BindsTo=B` only stops A
  when B stops, never the reverse, so without it
  `systemctl --user stop sway-session.target` leaves `graphical-session.target`
  and every service under it running, and the teardown silently does nothing.

  `quickshell-lock.service` is tracked here too but has **no `[Install]`
  section**: it is started on demand by `lock`, never pulled in by the target.
  It is `PartOf=graphical-session.target` so it still dies with the session.

  `install` ends with `systemctl --user daemon-reload` and
  `systemctl --user enable quickshell.service`, guarded on
  `-d /run/systemd/system` so macOS skips it; symlinking a unit is not enough,
  `WantedBy=` only applies once enabled. Editing an existing unit still needs a
  `daemon-reload`.

- **Autostart** (`.config/autostart/`): apps are started by **XDG autostart**,
  which uwsm runs, not by a sway `exec` block. Anything the compositor does not
  itself need goes here, so systemd owns its lifecycle; `sway/config` keeps only
  `sway-laptop-lid` and the `exec` that starts `sway-session.target`.
  `blueman.desktop` is a `Hidden=true` shadow, not a leftover. Working rules are
  in `.claude/rules/autostart.md` and the full notes, including why poweralertd
  runs with `-s` instead of any unit ordering, in
  `.claude/autostart-reference.md`.

- **Sway**: starts under **uwsm** as a systemd user unit —
  `wayland-wm@sway.desktop.service`, `ExecStart=/usr/bin/uwsm aux exec -- %I`,
  where the instance is the Desktop Entry ID (`sway.desktop`) and not the bare
  binary. Nothing in this repo launches the compositor: the greeter runs
  `uwsm start -- sway.desktop` (see Login), and from a VT `uwsm start default`
  does the same by hand, resolving through `~/.config/uwsm/default-id`. Both
  machines are on this path.

  It replaced a hand-written `/usr/local/bin/sway-run` launcher, which exported
  the Wayland variables itself, sourced a `.config/sway/profile` that no longer
  exists, and ran sway **without** `exec` so it could
  `systemctl --user stop sway-session.target` on the way out. Both are gone from
  disk now that a boot has come up clean on uwsm, and nothing references either.
  The trap while the two paths coexisted is worth keeping in mind when reading
  older notes: `sway/profile` was sourced by `sway-run` and by nothing else, so
  `QT_QPA_PLATFORMTHEME=kde` living in it was simply absent from the whole uwsm
  session, which is what left Dolphin unthemed.

  Under uwsm the session environment comes from `.config/uwsm/env` (tracked),
  which uwsm sources from `/usr/libexec/uwsm/prepare-env.sh` on the way up — a
  plain `. "$file"` behind an `-f`/`-r` test, so the symlink `install` leaves is
  sourced normally. It also reads a per-compositor `env-<desktop>` beside it and
  an `env.d/` directory, neither of which is used.

  **`~/.profile` does reach the uwsm session, and that is not obvious.**
  `prepare-env.sh` sources `/etc/profile` and `~/.profile` itself, then uwsm
  diffs the environment and pushes the result into the systemd user manager with
  `SetEnvironment` — so profile-only variables (`MBOX`, `NVM_DIR`,
  `DOCKER_CONFIG`, `EDITOR`, …) land in sway, in everything sway `exec`s,
  **and** in every user unit, quickshell included. That is strictly more than
  `sway-run` gave, where the user manager saw none of it — which is the whole
  reason `10-xdg.conf` exists. Do not read `environment.d`'s comment as meaning
  the graphical session lacks the profile; it means the _manager_ does not
  source it, and under uwsm something else does.

  It is conditional, but **not on there being a login shell** — an earlier
  version of this note said it was, and that was wrong. `__LOAD_PROFILE__` comes
  from `have_env_login`, which is simply whether `uwsm start` itself ran and
  left a non-empty environment behind: `save_env("env_login")` dumps
  `os.environ` just before uwsm replaces itself with the signal handler, and
  `prepare-env` reads it back (`/usr/share/uwsm/modules/uwsm/main.py`, around
  lines 2652 and 4836). So a greeter that execs `uwsm start` directly still
  loads the profile, which is what makes the gtkgreet flow below safe; what
  _would_ lose it is starting the compositor unit without going through
  `uwsm start` at all. Confirm from the journal rather than assuming — the
  preloader prints `Loading shell profile.` when it did, under the
  `uwsm_env-preloader` identifier.

  So `environment.d` is the floor, not the main path: it carries the XDG base
  directories the units would lose if the greeter ever started the compositor
  without going through `uwsm start`, plus session-wide non-shell settings like
  `QT_QPA_PLATFORMTHEME` that are not Wayland setup and so do not belong in
  `uwsm/env`. Everything else — tool configuration, `PATH`, editors — stays in
  `~/.profile` and already arrives; duplicating it into `environment.d` only
  creates two places to drift. Genuinely Wayland-session setup goes in
  `.config/uwsm/env`.

  One measurement to save repeating: a directory missing from the session's
  `PATH` is usually not a bug in any of this. `~/.profile` guards each entry
  with `[ -d ]` and runs once at login, so a toolchain installed mid-session is
  absent until the next one — `~/.local/share/cargo/bin`, created two hours
  after login, read exactly like a broken export and was not.

  uwsm sets `XDG_SESSION_TYPE`, `XDG_SESSION_DESKTOP`, `XDG_CURRENT_DESKTOP` (as
  `sway:wlroots`, not bare `sway`) and the XDG base directories itself, so
  `.config/uwsm/env` carries only what it does not: `MOZ_ENABLE_WAYLAND`,
  `QT_QPA_PLATFORM`, `SDL_VIDEODRIVER`, `_JAVA_AWT_WM_NONREPARENTING` and the
  cursor theme. Two variables `sway-run` exports are deliberately **not**
  carried over. `ELECTRON_OZONE_PLATFORM_HINT=auto` is unnecessary — measured,
  every Electron and Chromium app in the session (Chrome, Claude, Slack,
  Spotify) is already a native Wayland client without it, Claude with no flags
  at all. `ADW_DISABLE_PORTAL=1` is actively wrong here: it stops libadwaita
  reading the portal, and the portal's `org.freedesktop.appearance` is exactly
  how `theme`'s dark/light switch reaches GTK4 and Electron apps (see Themes).

  uwsm also owns the teardown that `sway-run`'s missing `exec` was for —
  `wayland-wm@sway.desktop.service` propagates its stop to
  `graphical-session.target` — so the compositor cannot outlive the session
  either way.

- **Login** (`system/greetd/`, `system/install-greetd`): greetd on VT7 runs a
  bare sway hosting gtkgreet, and choosing a session starts
  `uwsm start -- sway.desktop`. `system/` holds root-owned files for `/etc`,
  which are **copied, not linked**: `sudo ./system/install-greetd` after any
  edit. If the greeter fails, `Ctrl+Alt+F2` reaches a getty; test changes from a
  getty rather than from the session. Working rules are in
  `.claude/rules/login.md` and the full notes in `.claude/login-reference.md`.

- **NAS mounts** (`system/mounts/`, `system/install-mounts`): `//beedle/media`
  and `//beedle/backup` are CIFS automounts at `~/beedle/{media,backup}`, copied
  into `/etc` by `sudo ./system/install-mounts`. Two things live outside the
  repo and so need knowing here. `~/.ssh/config` (untracked) pins
  `IdentitiesOnly yes` and one `IdentityFile` per NAS host, because
  `Host * IdentityAgent` offering every key earns a DSM auto-block. And an SSH
  connection reset **before the banner** is that auto-block, not an
  authentication problem. Working rules are in `.claude/rules/nas-mounts.md` and
  the full notes in `.claude/nas-mounts-reference.md`.

- **Backup** (`.local/bin/backup`, `.config/backup_exclude`,
  `.config/systemd/user/backup-*`, and a bar indicator and browser in
  quickshell): an rsync-over-ssh `--link-dest` snapshot of `$HOME` to
  `backup@beedle:/volume1/backup/impa/amcoder` on daily, weekly and yearly
  systemd timers. Mail on this machine is broken, so whether a backup ran is
  answered on the NAS (`latest` and the `daily.N` mtimes), never by the mailbox.
  On beedle the key is restricted to `192.168.42.0/23` (the LAN is a /23, not a
  /24) and the `backup` user must stay in `administrators`, since DSM allows SSH
  only to that group. Working rules are in `.claude/rules/backup.md` and the
  full notes in `.claude/backup-reference.md`.
