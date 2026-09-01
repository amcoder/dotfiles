# Migrate the desktop shell to pure Quickshell

> Working document. Phases are independently shippable — pick one up by name
> ("let's do Phase 3") and it stands alone, with its own files, sway edits,
> verification and rollback. Tick phases off here as they land.
>
> - [x] 0 De-risk  · [x] 1 systemd  · [x] 2 Layout  · [ ] 3 Notifications
> - [ ] 4 Launcher/switcher/power  · [ ] 5 OSD  · [ ] 6 Wallpaper
> - [ ] 7 Lock + idle  · [ ] 8 Network/BT/audio panels  · [ ] 9 Additions
> - [ ] 10 uwsm (session, not shell — optional, gate on Phase 7)

## Context

The Sway desktop in this repo is assembled from a dozen independent programs — dunst, wofi,
zenity, swaylock, swayidle, swaybg, pasystray, nm-applet, blueman-applet — glued together by
shell scripts in `.local/bin/` and keybinds in `.config/sway/config`. Each one needs its own
config file, its own theme template, and its own reload mechanism, which is why
`.local/bin/theme` has grown to 573 lines with 13 render targets and a hand-tuned reload order.

Quickshell already owns the bar, tray, workspaces, battery, polkit agent, idle-inhibit and the
theme picker. Quickshell 0.3.0 on this machine ships first-class modules for essentially
everything still external. Consolidating means one process, one config language, one palette
source (`palette.json`, already watched and live-reloading), and far fewer moving parts.

There is a second motive. `.claude/sway-lockup-investigation.md` identifies a post-upgrade DRM
regression where a full modeset can lock up the session (`Failed to disable CRTC`). Its two
known triggers are `swaymsg reload` — which `theme set` performs on *every* theme switch — and
swayidle's `output * power off`. Moving the shell out of sway's `exec_always` and out of the
reload path removes both from the most frequently exercised code path in the repo.

**Decisions made up front:** icons means bar/menu iconography only (no desktop file icons);
all four external groups get retired; quickshell moves to a systemd user service; the directory
restructure happens first.

## Verified capabilities (checked on this machine, not assumed)

Quickshell 0.3.0 (`/usr/bin/quickshell`, Debian). Confirmed present:

- `Services.{Notifications, Mpris, Pipewire, SystemTray, UPower, Pam, Polkit}`
- `Networking` (NetworkManager: `networks`, `signalStrength`, `security`, `connectWithPsk`, `forget`)
- `Bluetooth` (BlueZ: `adapters`, `devices`, `pair`, `connect`, `battery`)
- `Wayland`: `WlSessionLock` + `WlSessionLockSurface`, `IdleMonitor`, `IdleInhibitor`, `Toplevel`/`ToplevelManager`, layer shell
- Core: `DesktopEntries`/`DesktopEntry`, `Quickshell.iconPath()`, `hasThemeIcon()`, the
  `image://icon/<name>` provider, `execDetached()`, `clipboardText`, `configDir`/`stateDir`/`dataDir`
- `mask` (a `Region`) exists on the window base type — click-through OSDs and wallpaper work

Findings that change the design:

1. **No global-shortcut protocol for sway.** Keybinds stay in `.config/sway/config` and call
   `quickshell ipc call <target> <fn>` — the pattern already at `config:286`.
2. **`graphical-session.target` is inactive** and nothing starts it. Two units in
   `~/.config/systemd/user/graphical-session.target.wants/` (`poweralertd`,
   `wayland-pipewire-idle-inhibit`) have been silently dead. The migration must create and start
   its own `sway-session.target`. `/etc/sway/config.d/50-systemd-user.conf` already does
   `systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP`.
3. **Under systemd the `XDG_*_HOME` vars and `~/.local/bin` on `PATH` are absent** — they come
   from `.profile`, which the user manager never sources. The unit must set them explicitly or
   `theme`, `messages` and `sway-*` become unreachable.
4. **Quickshell synthesizes a `qmldir` per directory** and registers the config root as module
   `qs` — so `import qs.services` works and singletons auto-register. Writing a `qmldir` by hand
   permanently *disables* synthesis for that directory. Do not write one.
5. **`qs -p <file>` roots the config at that file's parent**, so a second entry point
   `lock.qml` shares the same `qs.*` module tree while being a separate process.
6. **The wallpaper has two owners:** `/etc/sway/config.d/40-sway-background.conf` sets the Debian
   default and the generated `theme.conf:57` overrides it, forking swaybg. Deleting the generated
   line alone exposes the Debian wallpaper.
7. **dunst is untracked machine state:** a local build at `/usr/local/bin/dunst`, a user unit at
   `~/.local/share/systemd/user/dunst.service` (`Type=dbus`), and D-Bus activation via
   `/usr/local/share/dbus-1/services/org.knopwob.dunst.service`. Stopping it is not enough — it
   must be **masked**, or the next `notify-send` re-activates it into a name fight.
8. **Brightness needs no module and no `brightnessctl`:** `/sys/class/backlight/intel_backlight/brightness`
   is `root:video 0664` and the user is in `video`. `max_brightness` is 496.
9. **PAM will work.** `/usr/sbin/unix_chkpwd` is setgid `shadow` — the same mechanism swaylock
   uses — and `/etc/pam.d/swaylock` exists. Still worth a spike, but it is not the gamble it looks like.
10. **`get-icon` is already redundant** — `Quickshell.iconPath()` replaces it, retiring the
    PyGObject dependency.
11. `DesktopEntry` has **no `execute()`** in 0.3.0; the launcher builds argv from `entry.command` itself.

## Target architecture

### Process model

```
sway (from a VT via /usr/local/bin/sway-run)
 └─ exec systemctl --user start sway-session.target
        └─ BindsTo graphical-session.target
             ├─ quickshell.service                      Restart=always
             ├─ poweralertd.service                     (resurrected)
             └─ wayland-pipewire-idle-inhibit.service   (resurrected)

quickshell-lock.service   Restart=on-failure   — started on demand, NOT part of the target
```

The lock screen is a **separate process** (`lock.qml`, its own unit). If the shell crashes while
`WlSessionLock` is held, sway keeps the session locked — that is the protocol's security
guarantee — and you are looking at a black screen. Isolating the lock means every bar edit and
`systemctl --user restart quickshell` is lock-safe, and the lock process's dependency set is
tiny (`WlSessionLock`, `PamContext`, `SystemClock`, one `FileView`).

**Invariants:**
- Every escape hatch stays a *sway* keybind: `$mod+Return`, `$mod+Shift+q`, workspace switching,
  and lock must all work with quickshell dead. `StartLimitBurst=5` prevents a crash loop.
- **Apps launch via `swaymsg exec --`**, never as quickshell children — otherwise
  `systemctl --user restart quickshell` kills every app the launcher started (default
  `KillMode=control-group`). This also matches today's `set $menu ... | xargs swaymsg exec --`.
- `swaylock` and `swaylock.conf.tmpl` stay installed permanently as the themed emergency lock.

### Directory layout

Move from 20 flat files to (imports as `qs.config`, `qs.widgets`, …):

```
.config/quickshell/
  shell.qml  lock.qml  dev.qml        entry points (dev.qml instantiates one surface for testing)
  icons/  wallpapers/                 vendored SVGs; PNGs moved from .config/sway/
  config/     Theme Appearance Paths Icons          data only, no behaviour
  services/   *Service.qml, FocusedScreen           singletons: state + IpcHandler, no visuals
  widgets/    Icon Separator Button TextField Slider ListRow FilterList Fuzzy
  windows/    ModalOverlay BarPopup Osd Wallpaper
  modules/    bar/ launcher/ switcher/ power/ notifications/ osd/ polkit/ theme/ lock/ emoji/
```

Dependency rule: `widgets/` imports only `config/`; `windows/` adds `services/FocusedScreen`;
`services/` never imports `modules/` or `windows/`; `modules/` may import anything.

Avoid names that collide with imported Quickshell types — `modules/polkit/PolkitDialog.qml`,
not `PolkitAgent.qml`.

### Shared components (extracted from the duplication already in `Polkit.qml` / `ThemePicker.qml`)

- **`services/FocusedScreen.qml`** — the block copy-pasted at `Polkit.qml:19-29` and
  `ThemePicker.qml:9-19`, once. **Add a `Quickshell.screens[0]` fallback**: today both bind
  `screen: null` when nothing matches, and a null-screen `PanelWindow` is what produced
  `no output to auto-assign layer surface 'quickshell' to` in the lockup log.
- **`windows/ModalOverlay.qml`** — owns `screen`, four anchors, `ExclusionMode.Ignore`,
  `WlrLayer.Overlay`, `WlrKeyboardFocus.Exclusive`, scrim, blocking `MouseArea`, centred card,
  `Keys.onEscapePressed`, `forceActiveFocus()`. Props: `namespaceSuffix`, `dim`,
  `closeOnClickOutside`, `cardWidth`; signals `opened()`/`closed()`.
- **`widgets/FilterList.qml`** — the workhorse behind launcher, window switcher, power menu,
  emoji picker, wifi list and bluetooth list. Owns the search field, Up/Down/Home/End/PageUp/
  PageDown/Ctrl-N/Ctrl-P, wrap-around, keeping `currentIndex` valid as results shrink,
  `positionViewAtIndex`, hover→currentIndex, and forwarding unhandled keys to the field.
  Props: `model`, `keys`, `query`, `delegate`, `rowHeight`, `maxRows`; signals `accepted`,
  `secondary`, `cancelled`.
- **`widgets/Fuzzy.qml`** — subsequence match with prefix/word-boundary bonuses, ties broken by
  a caller-supplied weight (launcher = frecency, switcher = MRU). Keep it `.qml`, not `.js`.
- **`widgets/Button.qml`**, **`widgets/TextField.qml`** — `Polkit.qml:293-365` and `244-276`
  de-duplicated, with focus rings and Space/Return/Enter handling.
- **`windows/Osd.qml`** — transient card, `focusable: false`, and **`mask: Region {}`** so it is
  click-through; without the mask an overlay surface swallows pointer events for its whole lifetime.
- **`windows/BarPopup.qml`** — the anchored `PopupWindow` chrome `AptUpgrade.qml:220-246` hand-rolls.

IPC: keep one `IpcHandler` per service (`theme`, `launcher`, `power`, `windows`, `audio`,
`brightness`, `notifications`, `media`) plus a `shell` target with `restart()`/`status()`.
`qs ipc show` then documents itself.

## Phases

Each phase is independently shippable and separately revertable.

### Phase 0 — De-risk (no new surfaces)

Pure cleanup; stands alone and makes everything after it safer.

- `config:39` — `~/bin/sway-laptop-lid` → `~/.local/bin/sway-laptop-lid` (this has never run).
- `config:46` — delete `timeout 600 'swaymsg "output * power off"'` (lockup trigger #2).
- `config:262-282` — delete the dead `mode $session` block (nothing binds `mode $session`).
- `config:81` — `exec_always killall quickshell; quickshell` → `exec` (also removes the two
  cosmetic `Unknown/invalid command` errors sway logs for the `;`).
- `.local/bin/theme` `reload_all()` — drop `swaymsg reload`; add `apply_sway_colors()` issuing six
  targeted `swaymsg client.<state> '<title> <bg> <text> <indicator> <border>'` commands instead.
  `rename_workspaces()` already handles `$accentNN` live, so nothing else needed the reload.

**Verify:** switch themes 10×; borders and workspace colours update live;
`journalctl -b | grep -c 'Failed to disable CRTC'` stays 0.
**Rollback:** `git revert` + `swaymsg reload`.

### Phase 1 — Lifecycle: systemd user service

New tracked files under `.config/systemd/user/` (already covered by `install`'s
`find .config ... -type f`):

- `sway-session.target` — `BindsTo=graphical-session.target`
- `quickshell.service` — `ExecStart=/usr/bin/quickshell -p %h/.config/quickshell/shell.qml`,
  `Restart=always`, `RestartSec=1`, `StartLimitBurst=5`, `WantedBy=graphical-session.target`,
  and explicit `Environment=` lines for `XDG_CONFIG_HOME`/`XDG_STATE_HOME`/`XDG_DATA_HOME`/
  `XDG_CACHE_HOME` and `PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin` (finding 3).

`config:81` becomes `exec systemctl --user start sway-session.target`.
`/usr/local/bin/sway-run` (system file, documented in README): drop the `exec` and append
`systemctl --user stop sway-session.target`, or quickshell outlives sway and `Restart=always` spins.

**Landed.** Both resurrected units were kept (decision: yes to both). `ThemeService.commit()`
already used a plain `Process`, so nothing to drop there.

Three things the plan did not anticipate:

- **`BindsTo=` does not propagate stop in the direction the teardown needs.** `BindsTo=B` on A
  means A stops when B stops — not the reverse. So `systemctl --user stop sway-session.target`
  left `graphical-session.target` active and quickshell running, making the `sway-run` teardown a
  no-op. Verified by measurement, fixed with `PropagatesStopTo=graphical-session.target` on
  `sway-session.target`, which keeps `start`/`stop` symmetric on one unit name. The alternative —
  tearing down via `stop graphical-session.target` — also works but is asymmetric with the start.

- The sway `exec` chains the environment import into the same shell command,
  `exec "systemctl --user import-environment ... && systemctl --user start sway-session.target"`.
  `/etc/sway/config.d/50-systemd-user.conf` does its own import as a separate `exec`, and sway
  launches execs asynchronously, so the target could otherwise start before `SWAYSOCK` is imported.
  The quoting is what keeps `&&` from being parsed as a second sway command.
- `install` gained a `systemctl --user daemon-reload` plus a `systemctl --user enable` of both
  tracked units, guarded on `-d /run/systemd/system` so macOS skips it. Symlinking a unit is not
  enough — `WantedBy=` only takes effect once the unit is enabled.

The `XDG_*` vars and `~/.local/bin` ended up in `.config/environment.d/10-xdg.conf` rather than in
`Environment=` lines on the unit, which is where the plan put them. `environment.d` reaches *every*
user unit, expands `${HOME}` and `${PATH}`, and applies on a plain `daemon-reload` — confirmed with
`systemd-run --user`, which now finds `theme` on `PATH` with nothing declared unit-locally, so
Phase 7's `quickshell-lock.service` inherits it instead of duplicating five lines. Ordering caveat:
files are merged by filename across all `environment.d` directories, so nix's unprefixed
`nix-daemon.conf` sorts after `10-xdg.conf` and re-prepends its own paths; `~/.local/bin` still
lands ahead of `/usr/bin`, which is all that matters.

The unit keeps only `QT_QPA_PLATFORM=wayland` and `QT_QPA_PLATFORMTHEME=kde` — about how this shell
renders, not about the session. Both came from `sway-run`/`sway/profile` via inheritance, and
dropping the latter would silently change `Quickshell.iconPath()` icon-theme resolution.

`wayland-pipewire-idle-inhibit.service` moved from untracked machine state into the repo, gaining
the `PartOf=graphical-session.target` it was missing: with only `WantedBy=` it started with the
session but never stopped with it, and `Restart=always` would have spun it against a dead
compositor for the whole logout window. `install` backs the old real file up and symlinks over it.

Watch item, pre-existing and not introduced here: `systemd-analyze --user verify` reports ordering
cycles through `foot-server.socket`, which is both `WantedBy`/`After` `graphical-session.target`
and (being a socket unit) ordered `Before=sockets.target`, closing a loop back through
`basic.target`. The real start hits none of it — the journal is clean and all three services came
up — because systemd only pulls the whole graph into one transaction under `verify`. If a session
service ever fails to start with a broken-cycle message, `foot-server.socket` is the unit to mask.

**Verify:** `systemctl --user restart quickshell` leaves sway untouched; `swaymsg reload` no
longer restarts the bar; `journalctl --user -u quickshell -f` shows the shell's own log (today
it is buried in sway's `systemd-cat` stream); with quickshell *stopped*, `$mod+Return` still opens a terminal.
**Risk:** medium — a QML error at login means no bar. **Rollback:** restore the `exec_always`
line, `systemctl --user mask quickshell`, `swaymsg reload`.

### Phase 2 — Layout migration + shared components

The 20-file move, `import qs.*` added to every file (nothing survives untouched — today all
cross-file references resolve implicitly by directory), plus `FocusedScreen`, `ModalOverlay`,
`Button`, `TextField`, `ListRow`, and the `Theme`/`Appearance` split. Rewrite `PolkitDialog` and
`ThemePicker` on the new primitives. One commit, zero behaviour change.

**The trap:** `install` never removes stale symlinks, so after the move
`~/.config/quickshell/Bar.qml` etc. remain as dangling links to deleted files and quickshell dies
loading them. Add `.local/bin/dot-prune` (delete dangling symlinks under the four managed roots)
in this phase, since this bites on every future file move.

**Landed.** The tree is as planned. `FilterList` and `Fuzzy` were *not* built — they have no
consumer until Phase 4, and a workhorse widget written against no caller is a guess. `ListRow` was
built and has two consumers (`ThemePicker`, `AptUpgrade`); the identity chips in `PolkitDialog`
stayed hand-rolled, since a selection chip is not a button and contorting `Button` to cover both
would have cost more than it saved.

Notes from execution:

- Module synthesis was verified by spike before the move, not assumed: a throwaway config with
  `config/`, `widgets/` and `modules/bar/` confirmed `import qs.config` / `qs.widgets` /
  `qs.modules.bar` all resolve and that singletons auto-register across directories.
- **`config/Icons.qml` needs `Qt.resolvedUrl("../icons")`.** It resolves relative to its own file,
  so moving it into `config/` silently repointed the icon directory at `config/icons` — every icon
  would have rendered blank with no error in the log.
- **`widgets/TextField.qml` had to be a `FocusScope`**, not a `Rectangle` wrapping a `TextInput`.
  A QML function cannot override `forceActiveFocus()` (it is a C++ method on `QQuickItem`), so
  without the focus scope `ModalOverlay.focusItem` would have focused the frame and left the
  caret nowhere. `FocusScope` + `focus: true` on the inner `TextInput` delegates properly.
- `ModalOverlay` ended up with `opened()` and `dismissed()` rather than the planned
  `opened()`/`closed()`: escape and click-outside are a *request* to close, which the consumer
  answers differently (`ThemeService.hide()` vs `flow.cancelAuthenticationRequest()`), so naming
  it `closed()` would have inverted the meaning.
- `dot-prune` restricts itself to links whose target is inside `$DOTFILES_DIR`. Worth keeping:
  its first run swept ~150 *pre-existing* dangling links from long-dead setups (Slack, Spotify,
  obs-studio, per-theme `sway/nord.conf`-era files). All were already broken, so nothing readable
  was lost — but an unrestricted version would also have deleted unrelated broken links in
  `~/.config`, which are not this script's business.

**Verify:** `rm ~/.config/quickshell/*.qml && ./install && find ~/.config/quickshell -xtype l`
prints nothing; bar renders; `$mod+Ctrl+t` opens the picker; `pkexec true` prompts.

Verified end to end by screenshot: bar (workspaces, icons, tray) unchanged; picker opens on the
focused output with the current theme preselected, Down previews the next palette live on the bar,
Escape closes and clears the preview; `pkexec true` prompts with the field focused, a wrong
password shows "Authentication failed" and refocuses, Escape cancels; `theme set` across nord →
catppuccin-latte → catppuccin-mocha repaints live; `journalctl --user -u quickshell` clean and
`Failed to disable CRTC` still 0.

### Phase 3 — Notification daemon, popups, history

`services/NotificationService.qml` (`NotificationServer` with `bodySupported`,
`bodyMarkupSupported`, `imageSupported`, `actionsSupported`, `inlineReplySupported`,
`persistenceSupported`; a history ring buffer persisted to `Quickshell.stateDir` via
`FileView.setText()` — `PersistentProperties` survives a *reload*, not a restart; a `dnd` flag).
`modules/notifications/{NotificationPopups,NotificationCard,NotificationCenter}.qml` and
`modules/bar/NotificationIndicator.qml` replacing `Dunst.qml`. Popups follow
`FocusedScreen.screen`, matching dunst's `follow = keyboard`.

**Retires:** dunst binary + user unit + D-Bus service file, `.config/dunst/dunstrc`,
`dunst.conf.tmpl` and its `TARGETS` row, `dunstctl reload` in `reload_all()`, `Dunst.qml` —
**and the 255-activations-per-boot bug**, whose mechanism is exactly the two `dbus-send` calls
in `Dunst.qml:22` re-activating a momentarily-absent name owner. `notify-send` keeps working; it
is only a client.

**Cutover:** `systemctl --user stop dunst && systemctl --user mask dunst` (the mask is required —
finding 7), then restart quickshell. Confirm with
`busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications`.
**Sway:** `config:317` `dunstctl action` → `qs ipc call notifications invoke`; add `$mod+Ctrl+n`
(centre) and `$mod+Alt+n` (DND). **Rollback:** unmask and start dunst; it reclaims the name via
D-Bus activation.

### Phase 4 — Launcher, window switcher, power menu

All three sit on `FilterList`, and all three must land before wofi/zenity/`get-icon` can go.

- **Launcher** — `DesktopEntries.applications` filtered by `!noDisplay`, matched on name /
  genericName / comment / keywords / categories, frecency in `Quickshell.stateDir`. Build argv
  from `entry.command`, strip `%f %F %u %U %i %c %k`, launch via `swaymsg exec --`. Honour
  `workingDirectory` and `runInTerminal`. Expose `entry.actions` as sub-rows (net-new — today
  `wofi/config` sets `no_actions=true`).
- **Window switcher — use sway's tree, not `ToplevelManager`.** `ToplevelManager` has no
  workspace concept, and on a 19-workspace setup a switcher that cannot show or sort by workspace
  is a regression against `window-switcher.py`. Design: a long-lived
  `swaymsg -t subscribe -m '["window","workspace"]'` `Process` with a `SplitParser`, seeded by one
  `get_tree`; `ToplevelManager.activeToplevel` changes maintain the MRU order (sway exposes no
  focus history); activation via `swaymsg [con_id=N] focus`. Icons via
  `DesktopEntries.heuristicLookup(appId)?.icon` then `Quickshell.iconPath()`, keeping the alias map
  at `window-switcher.py:89-93`.
- **Power menu** — action table with single-letter accelerators reusing the dead `mode $session`
  mnemonics (l/o/s/h/r/p), plus `widgets/ConfirmDialog.qml` reproducing zenity's `--default-cancel`
  and `--timeout=10`. Lock dispatches `loginctl lock-session` (one code path, and it arms the
  sleep hook). **Drop "Reload Sway"** — it existed only for `theme`, and it is a lockup trigger.
  Close the menu before dispatching, so a polkit prompt never contends for exclusive keyboard focus.

**Retires:** wofi (all three consumers), `wofi.css.tmpl` + its `TARGETS` row, `.config/wofi/config`,
zenity, `.local/bin/system-menu`, `.local/bin/window-switcher.py`, `.local/bin/get-icon`, and with
them the last PyGObject/GTK dependency.
**Sway:** delete `set $menu`/`set $run` (24-25); 95/96/298 → `qs ipc call launcher toggle|run`;
97 → `windows toggle`; 283 → `power toggle`.
**Watch:** `qs ipc call` costs a process spawn per `$mod+Space`. Measure it. If perceptible, the
fallback is a long-lived `SocketServer` in the shell plus a tiny `.local/bin/qs-send`.

### Phase 5 — Volume and brightness OSD

Depends on Phase 3, or volume keypresses flood the new notification centre.

- **Audio:** `Pipewire.defaultAudioSink` / `defaultAudioSource`. **Gotcha:** Pipewire objects need
  an explicit `PwObjectTracker { objects: [sink, sink.audio] }` or every property reads as its
  default. This is the most common Quickshell/Pipewire mistake.
- **Brightness:** direct sysfs (finding 8). `FileView` on `.../brightness` with `setText()` and
  **`atomicWrites: false`** — the default write-then-rename is rejected by sysfs. `watchChanges`
  picks up firmware hotkeys. Fall back to `brightnessctl` on write error; hide the OSD when no
  backlight device exists.
- `windows/Osd.qml` + `modules/osd/{VolumeOsd,BrightnessOsd}.qml` + `widgets/Slider.qml`.

**Retires:** `.local/bin/volume`, `.local/bin/brightness`, `pamixer`, `brightnessctl` — and the
notify-send-as-OSD pattern, which is why volume changes currently pollute notification history.
**Sway:** 289-294 → `qs ipc call audio up|down|mute|micMute` and `brightness up|down`.

### Phase 6 — Wallpaper

`windows/Wallpaper.qml` — `PanelWindow`, `WlrLayer.Background`, `ExclusionMode.Ignore`,
`focusable: false`, `mask: Region {}`, `color: Theme.crust`, two stacked `Image`s with a
crossfade so a theme switch does not flash. **`sourceSize` must be bound to the screen** — a
5120×1440 output will otherwise decode at native size. Instantiate inside the existing
`Variants { model: Quickshell.screens }` in `shell.qml`.

`git mv` the five PNGs from `.config/sway/` to `.config/quickshell/wallpapers/` and update the
`wallpaper` key in all five theme JSONs. Change `sway.conf.tmpl:57` from the image to
`output * bg $crust solid_color` — this overrides the Debian default from
`/etc/sway/config.d/40-sway-background.conf` (finding 6) *and* leaves a themed backstop under
quickshell's layer, so a shell restart shows a matching colour rather than black or Debian blue.

### Phase 7 — Lock screen and idle

**Gate on a `PamContext` spike first** — a plain `PanelWindow`, no `WlSessionLock` anywhere,
`config: "swaylock"` (the file exists). `unix_chkpwd` being setgid `shadow` (finding 9) says this
should work, but confirm before building UI on it.

- `lock.qml` + `quickshell-lock.service` (`Restart=on-failure`, which *is* the crash recovery:
  a QML exception relaunches and re-locks; a clean `Qt.quit()` after unlocking does not).
  `WlSessionLockSurface` is instantiated once per screen automatically — that is the whole
  multi-monitor answer.
- `.local/bin/lock` starts the unit then polls for a stamp file `lock.qml` writes when
  `locked` goes true (~2s cap), so `before-sleep` cannot race a half-mapped surface.
- **swayidle is demoted, not deleted** — Quickshell 0.3.0 has no logind client, so nothing in the
  shell can hear `loginctl lock-session`'s Lock signal, which `$mod+Escape`, the power menu and
  kdeconnect all use. Reduce `config:42-47` to a policy-free adapter:
  `swayidle -w idlehint 120 lock 'lock' unlock 'systemctl --user stop quickshell-lock' before-sleep 'lock'`.
  All timeouts move into `services/IdleService.qml` (`IdleMonitor` at 240s → dim overlay, 300s → lock).
- **Screen-off must not be a modeset.** Draw an opaque black overlay covering every output
  instead. Real DPMS returns only as a per-output (`swaymsg output <name> power off`, never
  `output *`) opt-in, after the kernel question in the investigation is settled.

**Risk: high (lockout).** Mitigations in the verification section.
**Rollback:** restore swayidle's full line; `lock` → `swaylock -f`. `swaylock` and its template stay forever.

### Phase 8 — Network, Bluetooth and audio panels

Three services, three bar indicators, three `BarPopup` panels. Order within the phase:
audio → bluetooth → network, easiest first.

**Retires:** `pasystray`, `nm-applet`, `blueman-applet` (`config:84-86`) and the dead
`blueman-*` window rules at 349-351. **Keeps** 1password / kdeconnect-indicator / calibre, so
`Tray.qml` stays. Keep the `pavucontrol` and `nm-connection-editor` rules and surface them as an
"Advanced…" row in each panel.

**This phase last, deliberately — it has real feature gaps, and nothing here is broken today:**
- `nm-applet` is also NetworkManager's **secret agent** (VPN, 802.1x, captive portals).
  `Quickshell.Networking` has `connectWithPsk`/`connectWithSettings` but no agent registration,
  so an enterprise network fails silently. Scope the panel as "wifi + connectivity status", not
  an NM replacement. Check what `.local/bin/toggle-vpn` drives before removing anything.
- `blueman-applet` provides the BlueZ **pairing agent** (PIN prompts). Verify
  `Quickshell.Bluetooth.pair()` registers an `org.bluez.Agent1`; if not, new-device pairing still
  needs `bluetoothctl`.

New Phosphor icons to vendor (regular weight; `fill="currentColor"` → `#ffffff`, then `./install`):
`wifi-{high,medium,low,slash}`, `bluetooth{,-slash,-connected}`, `speaker-{high,low,none,slash}`,
`microphone{,-slash}`, `magnifying-glass`, `x`, `gear`, `power`, `sign-out`, `arrows-clockwise`,
`bed`, `caret-right`, `list`, `play`, `pause`, `skip-{back,forward}`, `calendar`.

### Phase 9 — Additions

MPRIS media widget (retires `playerctl`, `config:295-297`); calendar popup on the clock
(hand-rolled 7×6 grid from `Date`, ~40 lines, rather than pulling in `QtQuick.Controls`); emoji
picker on `FilterList` (retires `bemoji`, keeps `wtype`).

### Phase 10 — Move the session under uwsm

Numbered 10 because 8 and 9 were already taken; it is genuinely last, and unlike every other phase
it is about the session rather than the shell. Do it **after Phase 7**, when the lock service makes
session lifecycle the interesting part and there is something to gain.

Today the compositor starts the session manager: greetd autologins `sway-run`, a shell script that
exports Wayland env vars, and sway's own config does
`exec "systemctl --user import-environment ... && systemctl --user start sway-session.target"`.
That is the traditional sway-wiki arrangement and it works, but the dependency runs backwards —
systemd learns the session exists only once sway is already up, so unit ordering against the
compositor is approximate and every environment variable has to be hand-carried across the boundary
by `import-environment`.

[uwsm](https://github.com/Vladimir-csp/uwsm) inverts it: the compositor runs *inside*
`wayland-wm@sway.service`, and `graphical-session-pre.target` / `graphical-session.target` /
`graphical-session-post.target` become real ordering barriers rather than labels. Packaged on this
machine as `uwsm` 0.26.7+ds-2, not installed.

What it would replace:

- **`sway-run` entirely.** greetd's `initial_session` and `/etc/greetd/sway-config`'s gtkgreet line
  both become `uwsm start -- sway.desktop`. The env exports move to `~/.config/uwsm/env` (or stay in
  `environment.d`, which uwsm also honours), and the `.profile` sourcing is uwsm's job.
- **The `import-environment` dance**, which uwsm does itself, in the right order, before any unit
  that needs it starts.
- **The `PropagatesStopTo` teardown**, and with it the reason `sway-run` cannot be `exec`'d — uwsm
  owns shutdown, so a crashed compositor tears the session down deterministically instead of
  leaving `Restart=always` units spinning against a dead display.
- `sway-session.target`, replaced by uwsm's own target tree. `quickshell.service` keeps its
  `PartOf=`/`WantedBy=graphical-session.target` unchanged — that is the whole point of having
  targeted it rather than a sway-specific unit.

**Gate it on:** greetd + uwsm autologin working (uwsm expects a `.desktop` session entry and is
usually driven from a display manager's session list, which `initial_session` is not); and
`/etc/greetd/sway-config`'s gtkgreet path, which is a *second* consumer of the same launcher.

**Risk: high — it is the boot path.** Rehearse from a second VT with a root shell logged in, and
keep `sway-run` on disk until a full reboot has succeeded. **Rollback:** point greetd's
`initial_session` back at `sway-run`; nothing in `.config/` needs reverting, since the units are
already written against `graphical-session.target` rather than against sway.

**Not a prerequisite for anything.** Phases 2-9 are indifferent to which of the two arrangements is
in place, so this can be dropped entirely if the current one keeps working.

### Staying external, deliberately

`grimshot` (region-select + save + clipboard is a lot of work for no gain), `wtype`, the three
remaining tray apps, `pavucontrol` / `nm-connection-editor` / `blueman-manager` as escape hatches,
and `swaylock` as the emergency lock.

## Theming changes

`TARGETS` goes 13 → 11: `dunst.conf.tmpl` deleted in Phase 3, `wofi.css.tmpl` in Phase 4.
`swaylock.conf.tmpl` **stays** — one render, and it keeps the emergency lock themed.
`sway.conf.tmpl` shrinks to `client.*` colours, `set $accentNN`, and the solid-colour bg.

`reload_all()` ends up as:

```python
def reload_all(theme):
    notify_kde()
    clear_p10k_instant_prompt()
    reload_tmux()
    apply_sway_colors(theme)     # targeted swaymsg client.* commands
    rename_workspaces(theme)
    # no dunstctl reload, no notify-send, no swaymsg reload
```

Nothing needs to come last any more, so the ordering comment and `setsid --fork` both go. The
"Theme: X" toast moves into `ThemeService.commit()`, which now owns the notification server,
knows the label, and cannot lose the toast to a restart race.

Expose the rest of `palette.json` on the `Theme` singleton — `name`, `label`, `isDark`
(`appearance !== "light"`, exercised by catppuccin-latte), `wallpaper`, `iconTheme`, `accents`,
`ansi` — all generated today and unused. Move `fontFamily`/`fontSize`/`iconSize`/`trayIconSize`
(`Theme.qml:90-95`) and `barHeight` (hardcoded at `Bar.qml:17`) into `config/Appearance.qml`;
this is the same palette-vs-design split CLAUDE.md already argues for tmux.

Known rough edge: `Quickshell.iconPath()` resolves against the Qt icon theme, which under
`QT_QPA_PLATFORMTHEME=kde` comes from the generated `kdeglobals [Icons] Theme`. Qt caches it and
QML cannot call `QIcon::setThemeName`, so app icons may need one shell restart after a theme
switch. Not a blocker.

README: the touchpoint table loses the dunst and wofi rows; `sway/theme.conf` becomes "borders
only, applied by targeted `swaymsg` commands"; add the `sway-run` teardown line and the lock-screen
VT recovery command.

## Verification

**Per-file-change hygiene** — after every add or move:
`./install && find ~/.config/quickshell -xtype l` must print nothing.

**Reload semantics:** editing an existing `.qml` hot-reloads; a **new or moved** file needs a full
restart (`systemctl --user restart quickshell`), because registration is computed at load.

**Dev instance:** `qs -p ~/.dotfiles/.config/quickshell/dev.qml`, instantiating only the surface
under test. `-p` roots at the same directory so `import qs.*` resolves identically, and `qs list`
keys instances by config path. **Hard rule: `dev.qml` must never instantiate the notification
server, the polkit agent, or `SystemTray`** — those are singleton-by-D-Bus-name and will fight the
real shell.

**IPC:** `qs ipc show` enumerates targets; `qs ipc call launcher toggle` from a terminal is
byte-identical to what the sway binding runs.

**Notifications, in two stages:** build `NotificationCard`/`NotificationPopups` against a literal
fake model using the same field names while dunst still runs — that is 90% of the work with no
D-Bus involved — then add `NotificationServer` and cut over in one sitting. Test matrix:
plain, `-u critical`, `-t 0`, `-h int:value:40`, `-i firefox`, `-A yes=Yes -A no=No`,
replace-by-id (`-p` then `-r`), a 4KB body, 30 in a burst, and real senders (Chrome, kdeconnect).

**Lock screen — four layers, in order, with no unsaved work open and a VT reachable:**
1. `PamContext` spike in an ordinary window, no `WlSessionLock`.
2. Demo mode — `lock.qml` honours `QS_LOCK_DEMO` and renders `LockSurface` in a normal overlay
   `PanelWindow` that Escape closes. All layout/theme/prompt work happens here.
3. First real lock from a second VT with a root shell already logged in, having rehearsed
   `SWAYSOCK=$(ls /run/user/1000/sway-ipc.*.sock) swaymsg exec 'swaylock -f'` and
   `systemctl --user stop quickshell-lock`.
4. **Deliberately test the crash path once**: `systemctl --user kill -s KILL quickshell-lock`
   while locked. Record whether `Restart=on-failure` re-locks cleanly or whether sway refuses a
   replacement client an abandoned lock — **write the answer into `.claude/`**. That single fact
   decides whether the lock screen is safe to keep, and it is documented nowhere else.

**Idle:** an `IdleMonitor` with a 10s timeout in the dev instance, label bound to `isIdle`. Toggle
Insomnia, then separately play a fullscreen video, and confirm `isIdle` stays false in both cases.
**The second is the test that decides whether removing swayidle's timeouts is a regression** — it
establishes whether `respectInhibitors` honours *other clients'* inhibitors or only quickshell's own.

**Click-through:** with the OSD and wallpaper visible, click where they are and confirm the click
reaches the window underneath.

**After every phase:** `theme set nord`, `theme set catppuccin-latte` (light — exercises `isDark`),
`theme set catppuccin-macchiato`; the new surface repaints live; `journalctl --user -u quickshell`
is clean; `journalctl -b | grep -c 'Failed to disable CRTC'` is still 0.

## Open questions to settle during execution

- Does `respectInhibitors` see other clients' idle inhibitors? (Phase 7 gate.)
- Does `DesktopEntries` pick up newly installed `.desktop` files at runtime, or is a restart needed?
- Is `qs ipc call` latency acceptable on `$mod+Space` and on volume key repeat? If not, add
  `SocketServer` + `.local/bin/qs-send`.
- Does `Quickshell.Bluetooth.pair()` register an `org.bluez.Agent1`? (Phase 8 scope.)
- Does clipboard ownership survive the emoji picker closing, given the process stays alive?
