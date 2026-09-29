---
paths:
  - ".config/quickshell/**"
---

# Quickshell

Working rules for the shell. How each was established, what was measured and
what was tried first is in `.claude/quickshell-reference.md`; read the relevant
part there before changing any mechanism described here.

## Running it

- Entry points: `shell.qml` (the shell), `lock.qml` (lock screen, its own
  process), `backups.qml` (backup browser, its own process), and `dev.qml` for
  working on one surface (`quickshell -p ~/.dotfiles/.config/quickshell/dev.qml`).
  Never instantiate the polkit agent, `SystemTray` or a notification server in
  `dev.qml`: each claims a D-Bus name and fights the running shell.
- `systemctl --user restart quickshell` restarts it, `journalctl --user -u
  quickshell` is its log. QML edits hot-reload, but a **new** file (a singleton
  especially) needs a restart or the shell dies with "X is not defined".
- A new, renamed or moved file needs `./install`, and a dangling old link kills
  the shell at load: `find ~/.config/quickshell -xtype l` must print nothing.

## Layout

- `config/` is data only (`Theme` palette, `Appearance` design, `Paths`,
  `Icons`). `services/` are singletons owning state and `IpcHandler`s, no
  visuals. `widgets/` import only `config/`. `windows/` may add
  `services/FocusedScreen`. `modules/<feature>/` may import anything.
- Never write a `qmldir` by hand: it permanently disables synthesis for that
  directory.
- A template or palette change goes in `Theme`; fonts, sizes and bar height go
  in `Appearance`.

## QML and Quickshell traps

- **A singleton is created on first reference.** An IPC-only service never
  registers its `IpcHandler` unless something binds to it unconditionally (a
  reference inside a short-circuited conditional does not count). Every such
  service here is warmed by a `visible:` or similar binding; keep it that way.
- `DesktopEntries`, `Networking`, `Mpris.players` and Pipewire defaults are
  empty or null at `Component.onCompleted` and fill in asynchronously. Read
  them through bindings, never once.
- `Quickshell.env()` returns `null` for an unset variable: test `!!env(…)`.
- `StdioCollector.data` is bytes; the string is `.text`.
- `children` is read-only on every QML object, and `native` is reserved even
  as a local: neither can be a function or variable name.
- A signal handler written at an instantiation site replaces the component's
  own rather than running beside it.
- A QML template literal eats backslashes and `${…}`: embedded shell or awk
  must use neither (see `LauncherService`'s awk).
- `image://icon/` draws a pink checkerboard for a missing name and reports
  `Ready`. Resolve icons through `Quickshell.iconPath(name, true)` (returns `""`
  when missing) or `iconPath(name, fallbackName)`.
- `FileView`: `path: ""` is silent; a watch on a path that does not exist yet
  never fires when it appears (retry on a timer); the watch survives a rename;
  writing sysfs needs `atomicWrites: false`.
- A clipboard write takes the Wayland selection only from inside an input
  event handler.
- `WheelHandler` does not fire where a `MouseArea` does; use a `MouseArea`
  with `acceptedButtons: Qt.NoButton` so clicks still pass.

## IPC

- Sway reaches the shell only through `quickshell ipc call <target> <fn>`.
- Name functions `open`/`close`, never `show` (swallowed by the CLI's own `ipc
  show`).
- `ipc call` exits 0 when the call did not land, printing `Target not found.`
  or `Function not found.` on stdout; 255 means no shell running. Check both.
- It reinterprets JSON-looking arguments: pass structured data through a file.

## Windows and surfaces

- Launch apps with `I3.dispatch("exec …")`, never a `Process`, which would die
  with every shell restart. `exec` takes no `--`. The screen recorder is the
  one deliberate exception.
- **Never use `PopupWindow` for anything that takes keys**: it cannot hold
  keyboard focus. Panels are `windows/BarPopup`, a `ModalOverlay` with an
  `anchorItem`.
- `WlrLayershell.keyboardFocus` applies only when the surface is created: hold
  a constant `Exclusive` and toggle `visible`, as `ModalOverlay` does.
- A `PanelWindow` is visible by default; a dropdown must say `visible: false`.
- `BarPopup`: dismiss with `expanded = false`, never `visible = false`. A popup
  opened both by click and by IPC assigns `expanded` from a `Connections`
  rather than binding it. Keep `visible: expanded || cardHeight > 0`.
- A list must never reorder under the cursor: sort by name or label, never by
  state or signal strength, and give lists whose rows arrive late a fixed
  height.
- Click-through surfaces use `mask: Region {}`.
- Modal surfaces bind `screen` to `FocusedScreen.screen`. A per-bar instance
  gates on its own bar's screen, read off its anchor item and not off the
  window's own `screen`.

## Bar

- `modules/bar/Bar.qml` has `left`, `centre`, `right`, each full height, items
  spaced 12, the clock held off 20 either side. The centre is an `Item`, not a
  `Row`: the clock is pinned to the middle and everything else hangs off its
  edges, with a `Row` on its left so hidden indicators drop out. Items are
  grouped by kind; see the reference before moving one.
- Workspace labels come from `set $wsN` in `.config/sway/config`; each value is
  double-quoted (load-bearing) and drawn as `Text.PlainText`.
- Icons are vendored Phosphor (regular weight) in `icons/`, with
  `fill="currentColor"` replaced by `fill="#ffffff"`, drawn by
  `widgets/Icon.qml`. Recolour in the SVG, never with `MultiEffect`.
- Applets kept running only for a D-Bus role are hidden by id in `Tray.qml`'s
  `hidden` list (`nm-applet`).

## Areas

- **Theme picker**: highlighting sets `Theme.preview`/`previewWallpaper`;
  `commit()` does not clear the preview, `hide()` does.
- **Wallpaper**: `WlrLayer.Bottom`, not `Background`. No `sourceSize` (center
  mode means no scaling). Crossfade only for changes nobody watched; preview
  swaps are instant. New wallpapers go through `themes/unmat-wallpaper`.
- **Notifications** (replaced dunst, which is masked): `expireTimeout` is ms,
  -1 means default. `notify-send -i` lands in `image`, not `appIcon`.
  Replacing by id mutates the object in place with no new signal, so cards
  read the live `entry.notification`. `trackedNotifications` lags the
  `notification` signal; the service keeps its own arrays. The popup cap is in
  the view. The popup stack is a focus-less `PanelWindow`, not a `BarPopup`.
- **Launcher**: `DesktopEntry.command` is already the stripped argv;
  `NoDisplay` is already filtered; `OnlyShowIn`/`NotShowIn` are not, so
  `LauncherService` re-reads the desktop files. `FilterList`: `fields` fall off
  multiplicatively, `weight` is added to the score, Home/End only via
  `TextField.keyHandlers`.
- **Window switcher**: the list is sway's tree from the service's own `swaymsg
  subscribe`, MRU from the `focus` arrays; row 1 is preselected.
- **Window cycler** ($mod+Tab): sway cannot see the Super release, so the
  surface catches it inside a nearly empty `$cycle` mode, and the shell
  returns to `mode default` on every exit path. The thumb button's binding is
  scoped to the mouse and never switches modes. Thumbnails come from
  `.local/bin/window-thumbs` (`grim -T`) at 1280px physical; both Images in a
  cell share `sourceSize`; the capture batch must outlive the gesture. No
  hover selection. Test with `quickshell ipc call windows next` and `wtype -P
  Super_L -p Super_L`; with `wlrctl`, scroll 10 is one notch.
- **Power menu**: suspend and hibernate are gated on logind's `Can*`.
  `CountdownDialog` accepts at zero, focuses accept, and `Button` ignores key
  autorepeat.
- **OSD, audio, brightness**: one OSD surface for all sources. Pipewire lists
  filter on node `type` (readable untracked) and then track; sort by label;
  writing `preferredDefaultAudioSink` sets the default and the tick follows
  the effective one. Brightness writes sysfs directly with `atomicWrites:
  false` and `onSaveFailed: reload()`, floor one raw unit.
- **Bluetooth**: Quickshell has no BlueZ agent, so no pairing or discovery in
  the panel; "advanced…" opens `blueman-manager`.
- **Network**: nm-applet stays resident as NetworkManager's secret agent. The
  scanner runs only while the panel is open. VPNs come from `nmcli`; split its
  `-t` output from the right.
- **Media**: `MprisService` rebuilds from an `Instantiator` over the
  `Mpris.players` model (not `.values`), filters out non-media players, and
  sets `activeName` on appearance as well as on play. `position` extrapolates
  locally.
- **Calendar**: always six rows.
- **Emoji**: copy and paste run straight from the activation handler; paste is
  a sway `exec` after a 100ms sleep. Test pastes in a GUI field, not a
  terminal.
- **Polkit**: `PolkitDialog`, once, in `shell.qml`. Report failures from
  `authenticationFailed`.
- **Lock**: `lock.qml` runs as `quickshell-lock.service` with
  `QS_DISABLE_FILE_WATCHER=1` (a reload while locked is fatal). `secure` is the
  surfaces-up signal and writes the stamp `lock` waits for. `ExecStop` unlocks
  over IPC. Test a real lock in a nested sway with its socket bound once.
- **Idle**: swayidle owns every timeout; `IdleService` is only a `dimmed` flag
  and an `IpcHandler`.
