# Quickshell reference

The full notes behind `rules/quickshell.md`: how each fact there was
established, what was measured, and what was tried first. Moved verbatim from
CLAUDE.md.

**Quickshell** (`.config/quickshell/`): the Wayland status bar, built with
[Quickshell](https://quickshell.outfoxxed.me/) (QML). It replaces
swaybar/i3blocks; sway declares no bar of its own and does not start it directly
— `quickshell.service` does, via `sway-session.target` (see the systemd section
below). `shell.qml` is the entry point, defining a `PanelWindow` top bar per
screen (`modules/bar/Bar.qml`). Colors come from `config/Theme.qml`, which reads
the generated `~/.config/quickshell/palette.json` through a `FileView` with
`watchChanges`, so a theme switch repaints the bar with no restart; its
hardcoded Catppuccin values are only fallbacks for before the file loads. Every
colour is still a binding, so `readonly` properties update fine. QML edits
hot-reload — but a **new** file (a new singleton especially) needs a full
restart, since hot-reload will not register it and the bar dies with "X is not
defined". Restarting means `systemctl --user restart quickshell`, and its log is
`journalctl --user -u quickshell` rather than sway's `systemd-cat` stream.
`swaymsg reload` does not restart the bar, and a theme switch does not reload
sway at all.

The tree is `config/` (`Theme`, `Appearance`, `Paths`, `Icons` — data, no
behaviour), `services/` (singletons owning state and `IpcHandler`s, no visuals),
`widgets/` (leaf components importing only `config/`), `windows/` (window
chrome, adding `services/FocusedScreen`) and `modules/<feature>/`, which may
import anything. Quickshell synthesizes a `qmldir` per directory and registers
the config root as module `qs`, so `import qs.services` works and singletons
auto-register across directories — **do not write a `qmldir` by hand**, which
permanently disables synthesis for that directory. `dev.qml` is a second entry
point for working on one surface at a time
(`quickshell -p ~/.dotfiles/.config/quickshell/dev.qml`); `-p` roots the config
at the same directory so `import qs.*` resolves identically. Never instantiate
the polkit agent, `SystemTray` or a notification server there — each claims a
D-Bus name and would fight the running shell.

`Theme` is the palette and `Appearance` is the design (fonts, icon sizes, bar
height), the same split CLAUDE.md argues for tmux: a theme switch touches only
the first. `services/FocusedScreen` resolves the output holding the focused sway
workspace and every modal surface binds `screen` to it; it falls back to
`Quickshell.screens[0]` because a `PanelWindow` on a null screen fails to map
with "no output to auto-assign layer surface to". `windows/ModalOverlay` owns
the whole overlay-layer-surface pattern — exclusive keyboard focus, scrim,
blocking `MouseArea`, Escape, and a card that is centred or, given an
`anchorItem`, hung under it — and its children become the card's column;
`PolkitDialog`, `Launcher`, `WindowSwitcher` and every `BarPopup` are built on
it, along with `widgets/{Button,TextField,ListRow,FilterList}`. An anchored card
re-measures its position on every open, because bar items shift as their
neighbours change width — the notification bell moves the moment its unread
count gains a digit. `windows/CountdownDialog` is a `ModalOverlay` too — it
lives in `windows/` rather than `widgets/` because a widget may import only
`config/`. It is named for what it does rather than `ConfirmDialog`, which stays
free for an ordinary wait-for-an-answer dialog.

`widgets/FilterList` is the search-field-over-a-scored-list behind the launcher,
the switcher and the session menu. The caller supplies `source`, a `fields`
function returning searchable strings most-significant-first, an additive
`weight`, and a full `ListView` delegate that reads `ListView.isCurrentItem` and
sets `ListView.view.currentIndex` on hover. Three things it settles that are
easy to get wrong:

- **`fields` falls off multiplicatively** (`fieldFalloff`, 0.55 per position),
  not by a fixed subtraction. A prefix hit in a long _comment_ scores higher
  than a mid-word hit in a _name_, so a small penalty leaves "chr" ranking some
  screensaver's description above Google Chrome.
- **`weight` is added to the score, not used as a tie-break.** Scores are rarely
  equal, so a tie-break never fires where it matters; adding frecency is what
  lets a daily-used app outrank an unrelated prefix match. With an empty query
  every score is 0, so `weight` alone orders the list — which is how the
  launcher shows frecency order and the switcher MRU order. It also means the
  _source_ order is the final fallback, so `Launcher` sorts its entries by name:
  unsorted, a fresh install lists apps in `DesktopEntries` scan order.
- **Home and End are only reachable through `TextField.keyHandlers`.** A
  `TextInput` accepts them for cursor movement, so a `Keys` handler further up
  the focus chain never sees them; `keyHandlers` binds `Keys.forwardTo` on the
  inner input, which gets first refusal on every key.
  Up/Down/PageUp/PageDown/Ctrl-N/Ctrl-P need no such help — a single-line
  `TextInput` ignores them and they bubble.

`searchable: false` drops the field entirely and gives the list focus, which is
what frees bare letters for accelerators — `PowerMenu` uses it for its
`l`/`w`/`q`/`o`/`s`/`h`/`r`/`p` mnemonics, most of them carried over from the
sway `mode $session` block it replaces; `s` and `h` are conditional, so `h` is
simply absent on a host that cannot hibernate. `TextField` is a `FocusScope` so
`forceActiveFocus()` on the field reaches the inner `TextInput`.

Renaming or moving a file here needs `./install` (to create the new link) and
leaves a dangling old link that `dot-prune` removes — `install` runs it, but a
stale link left in place kills the shell at load.
`find ~/.config/quickshell -xtype l` must print nothing.

Icons are vendored Phosphor SVGs in `icons/`, drawn by `widgets/Icon.qml` as
`Icon { name: "bell"; color: Theme.yellow }`. `config/Icons.qml` reads the SVG
through a `FileView` and caches it (its `Qt.resolvedUrl("../icons")` is relative
to `config/`, not to the config root); `Icon.qml` swaps the file's `#ffffff`
placeholder fill for the requested colour and hands the result to `Image` as a
`data:` URI. Recolouring has to happen in the SVG markup — tinting the rendered
image with `MultiEffect` (either `colorization` or an alpha mask) blows out thin
strokes at bar sizes until enclosed shapes fill in solid. To add an icon, drop
the file from [Phosphor](https://phosphoricons.com/) (regular weight) into
`icons/`, replace its `fill="currentColor"` with `fill="#ffffff"`, and re-run
`./install`.

Workspace icons are named by sway: each `set $wsN` in `.config/sway/config`
carries a `<span foreground='...'>icon-name</span>`, and
`modules/bar/Workspaces.qml` parses the span for the colour and the icon name.
Sway only applies renamed workspaces to newly created ones, so after editing
those lines, existing workspaces keep their old names until
`swaymsg rename workspace` is run or they are recreated. Each value is
**double-quoted**, and that is load-bearing: sway names the workspace that
already exists at startup after the `workspace number` binding mentioning it
(`workspace_next_name`), and that path strips one level of quoting where the
runtime `workspace number` command does not. Unquoted, the first workspace comes
up as `1: 1 <span foreground=#89b4fa>envelope</span>` — the colour's quotes
gone, so the span no longer parses — and the bar shows the icon's _name_ as text
until you switch away and back, which recreates the workspace through the
ordinary path. Quoting in the `bindsym` instead works identically; quoting in
both cancels out. `Workspaces.qml` draws the label as `Text.PlainText` so a name
that does fail to parse is at least visibly raw markup: under `AutoText` it is
rendered as rich text, which is what turned the broken name into a
plausible-looking `1 envelope`.

`modules/bar/Bar.qml` lays out three sections — `left`, `centre`, `right` — each
full height, so an item can measure against `parent.height`. A new item goes
into whichever section it belongs in. Nothing is drawn between items and every
section spaces its own at 12 — the systray included, so a tray icon sits at the
same pitch as a built-in one and the run reads as one row rather than two. The
clock alone is held off at 20 either side, since the groups beside it are what
change width. The centre is positioned against the bar's own centre rather than
laid out between the other two, so the clock stays put no matter what grows on
either side; it also means the sections can overlap if one ever gets wide
enough, which at these widths they do not.

Items are grouped by **kind**, not by history. `right` runs systray, theme,
insomnia, system monitor, display, audio, bluetooth, network, battery, power:
the tray sits at the section's left end because its contents are whatever
happens to be running, and the items whose state one glances at are gathered at
the edge. The centre carries the **notices** on the clock's left — apt, mail,
idle inhibit, notifications, privacy, recorder — every one of which is absent or
dark most of the time, and the media item on its right. Workspace buttons carry
their gap as padding _inside_ each button (6px a side, `spacing: 0`), so the
focused pill abuts its neighbours rather than floating in a gap of bar
background.

`left` and `right` are `Row`s, but the **centre is not**: a Row would slide the
clock left by half of whatever was added beside it. It is an `Item` spanning the
full bar width, with the clock pinned to `horizontalCenter` and everything else
anchored off the clock's own edge so it grows outward — measured invariant at
the bar's centre line (±0.5px, glyph bearings) while the media item's width
moved 184px → 120px across a track change. Spanning the bar shadows nothing,
since a bare `Item` takes no input and only the children do.

The bar is always visible and reserves its own height via `ExclusionMode.Auto`,
so windows start below it.

`services/ThemeService.qml` holds the theme list read from the generated
`themes.json` and owns an `IpcHandler` on target `theme`, so
`quickshell ipc call theme toggle` opens the picker from a sway keybind
($mod+Ctrl+t); `modules/bar/ThemeToggle.qml` is the palette icon in the bar.
`modules/theme/ThemePicker.qml` is the view, a `BarPopup` hung under that
palette icon and so instantiated in `ThemeToggle.qml` rather than in
`shell.qml`, one per bar with a focused-screen gate. Its `expanded` is
_assigned_ from a `Connections` on `active` rather than bound to it, because
`BarPopup` clears `expanded` on dismiss and an assignment would break a binding
for good — the same arrangement the notification centre uses, and for the same
reason: both are opened over IPC as well as by their bar item. Those bindings
are also what warms `ThemeService`, which is otherwise reached only through a
click handler and an `IpcHandler`, and so would never register that handler at
all. Highlighting a row sets `Theme.preview` and `Theme.previewWallpaper`, which
override the loaded palette so the running bar, the picker's own card and the
wallpaper preview that theme. **`commit()` deliberately does not clear the
preview** — only `hide()` does, on escape or click-outside. Clearing it at
commit drops the desktop back to the old theme for as long as `theme set` takes
to write the new palette, which is a blink for the colours and a full-screen
flash for the wallpaper; `Theme` ends the preview instead when the new
`palette.json` loads. Only quickshell previews live — everything else changes on
commit.

`services/NotificationService.qml` is the session's notification daemon,
replacing dunst (stopped and **masked** — `systemctl --user mask dunst`; the
local binary, its user unit and its D-Bus service file are left on disk so the
rollback is `unmask` + `start`). It owns the `NotificationServer`, the popup
queue and a 100-entry history ring buffer persisted to
`Quickshell.statePath("notifications.json")`, whose directory is keyed by a hash
of the config path — so `dev.qml` gets its own history and cannot clobber the
real one. `modules/notifications/NotificationPopups.qml` is the transient stack
and `NotificationCentre.qml` the history view; both hang under
`modules/bar/NotificationIndicator.qml`'s bell, so both are instantiated there
rather than in `shell.qml` and there is one of each per bar. The centre is a
`BarPopup`; the stack cannot be one, because a `ModalOverlay` takes exclusive
keyboard focus and covers the screen with a click-catcher — every arriving
notification would steal the keyboard and swallow the next click. It stays a
focus-less `PanelWindow` masked down to its card and borrows only the look,
through `widgets/AttachedOutline`. Being per-bar, `screen: FocusedScreen.screen`
becomes a gate on the bar's own screen, which is what still matches dunst's
`follow = keyboard`; read that screen off the anchor item and **not** off the
window's own `screen`, which Quickshell resolves as the window maps and so loops
back through `visible`. The centre's `expanded` is _assigned_ from a
`Connections` on `centreVisible` rather than bound to it, because `BarPopup`
clears `expanded` on dismiss and an assignment would break a binding for good.
Sway calls it at `config:311-313` — `$mod+n` invokes the newest notification's
default action (what `dunstctl action` did), `$mod+Ctrl+n` opens the centre,
`$mod+Alt+n` toggles do-not-disturb.

Three things about the freedesktop API as Quickshell 0.3.0 exposes it, each
established by spike rather than assumed. `Notification.expireTimeout` is
**milliseconds** passed straight through from D-Bus, with `-1` meaning "server
default" (5s/10s/never by urgency, matching the old `dunstrc`).
`notify-send -i <name>` arrives as the `image-path` hint and lands in
`notification.image` as an `image://icon/<name>` URL, _not_ in `appIcon` — so
`image` is the primary icon source and `appIcon` only the fallback. And
`trackedNotifications` has not yet been updated when the `notification` signal
fires, so the service keeps its own arrays rather than reading that model.

**The `image://icon/` provider draws a pink-and-black checkerboard for a name no
theme has, and reports it as `Ready`.** So an `Image` cannot tell a missing icon
from a real one; `Quickshell.iconPath(name, true)` can, returning `""` for a
missing name or path (it takes a bare absolute path but not a `file://` URL).
`NotificationCard` resolves every icon through it, which is what keeps uwsm's
`fumon` (`notify-send -i dialog-info`, a name that does not exist; the real one
is `dialog-information`) from drawing the placeholder. An `image://qsimage/<id>`
URL is the notification's raw image data held in the shell's memory, so a
history entry restored after a restart fails to load it (`Error`, not a
placeholder) and the card falls back to the app icon.

**Replacing a notification by id mutates the existing `Notification` in place
and emits no new `notification` signal.** A record holding a copy of the fields
therefore goes stale, which is why `NotificationCard` reads the live object
through `entry.notification` and falls back to the stored copy only once the
notification is gone (restored from disk, or closed by its sender).
`summaryChanged`/`bodyChanged` are the only "this was replaced" signal on offer;
they drive re-popping an already-expired notification, moving it back to the top
of history, and re-saving.

The popup cap (5) lives in the view, not the service, so notifications past the
cap still expire on their own schedule and are only _hidden_ behind an "N more"
row — which is what dunst's `indicate_hidden` did. `IpcHandler` functions are
`open`/`close`, not `show`/`hide`: `quickshell ipc call <target> show` is
swallowed by the CLI's own `ipc show` subcommand (this bites `theme show` too).

`services/LauncherService.qml` + `modules/launcher/Launcher.qml` replace
`wofi --show=drun` and `--show=run`, `services/WindowService.qml` +
`modules/switcher/WindowSwitcher.qml` replace `window-switcher.py`, and
`services/PowerService.qml` + `modules/bar/Power.qml` +
`modules/power/PowerMenu.qml` replace `system-menu` and its zenity
confirmations. Sway calls all three over IPC — `$mod+Space` (`launcher toggle`),
`$mod+Shift+Space` (`launcher run`), `$mod+Alt+Space` (`windows toggle`),
`$mod+Shift+Escape` (`power toggle`). wofi, zenity, `system-menu`,
`window-switcher.py` and `get-icon` are gone, and with them the last
PyGObject/GTK dependency; the wofi and zenity binaries are left installed but
unused.

**Apps are launched with `I3.dispatch("exec …")`, never a `Process`.** Sway runs
`exec` through `/bin/sh` (so the argv from `entry.command` has to be
shell-quoted back into a line), and the resulting process lands in sway's own
session scope rather than `quickshell.service`'s control group — verified by
reading `/proc/<pid>/cgroup` and by watching a launched window survive
`systemctl --user restart quickshell`. As a quickshell child it would be killed
with the shell on every restart. `exec` takes no `--`;
`I3.dispatch("exec -- cmd")` silently does nothing.

Four things about `DesktopEntries` in 0.3.0, each established by spike:

- **The scan starts on the first read of the model and fills in
  asynchronously.** Reading `DesktopEntries.applications.values` for the first
  time inside `show()` returns an empty array and opens an empty launcher; the
  model is only populated a moment later, entry by entry (`valuesChanged` fires
  per entry). `LauncherService.applications` is a plain binding for exactly this
  reason — instantiating `Launcher` in `shell.qml` is what warms it at startup.
- **`command` is already the `%`-code-stripped, shell-unquoted argv.**
  `execString` keeps `%u`/`%F` and the quoting; `command` is a real string list
  with them removed. There is nothing to strip by hand.
- **`NoDisplay=true` entries are excluded from the model already** (277 files on
  disk, 228 in `values`, `noDisplay` false for all of them), so filtering on
  `!noDisplay` is a no-op. **`OnlyShowIn`/`NotShowIn` are not applied, and not
  exposed either** — see below.
- **New `.desktop` files are picked up at runtime** — no restart needed.

Because `DesktopEntry` exposes neither `OnlyShowIn` nor `NotShowIn`,
`LauncherService` re-reads the `.desktop` files itself in a one-shot `Process`
and keeps the ids to hide in `hidden`. This is not pedantry: 107 xscreensaver
hacks ship `OnlyShowIn=MATE;` from `xscreensaver-gl`/`xscreensaver-data` under
`/usr/share/applications/screensavers/`, and with the lxqt and GNOME
control-centre panels they were **129 of 228 entries** — the launcher shows 99
with the filter on. The id is the path below `applications/` with `/` turned
into `-`, which is the spec's desktop-file ID and what `DesktopEntry.id` holds.

**That embedded script must contain no backslash and no `${…}`.** It lives in a
QML template literal, where `\/` collapses to `/` and `\[` to `[` — which turns
an awk regex into a syntax error, and since the failure is on stderr the only
symptom is that nothing gets filtered. The awk is written with
`index()`/`substr()` and string-form regexes for exactly this reason, and the
shell side splits `XDG_DATA_DIRS` with `IFS=:` rather than `tr : '\n'`. The scan
runs once at startup, so a desktop-restricted entry installed mid-session is not
re-checked.

`Quickshell.iconPath(name, true)` returns `""` when the icon is missing, and
`Quickshell.iconPath(name, fallbackName)` returns a URL carrying `?fallback=`,
which is what the launcher and switcher use so a missing app icon still renders
something. It logs a burst of
`qt.svg.draw: The requested buffer size is too big` for a handful of oversized
system SVGs on the first open after a restart, then never again — Qt caches per
icon.

**The window switcher takes its list from sway's tree, not `ToplevelManager`**,
which has no workspace concept. `Quickshell.I3` exposes only `workspace` and
`output` events through `rawEvent`, so `WindowService` runs a
`swaymsg -r -t subscribe -m '["window","workspace"]'` of its own (`-r` gives one
JSON object per line, which `SplitParser` wants) and re-reads `get_tree` on
every event, debounced 40ms. There is no hand-maintained MRU: **sway's
per-container `focus` arrays are the focus history**, so walking children in
that order yields the MRU list directly and it cannot drift. The switcher
preselects row _1_, not 0 — row 0 is always the focused window, so starting
below it makes a single press an alt-tab.

`modules/switcher/WindowCycler.qml` is the alt-tab: **$mod+Tab** taps through to
the last-focused window with nothing drawn at all, while holding Super brings up
a grid of large window previews that Tab and Shift+Tab move through, committed
by releasing Super. It shares `WindowService` with the search list above — the
same MRU order, snapshotted at the start of the gesture rather than read live,
since committing a choice re-sorts the list and would scramble the indices under
the picker.

**Sway cannot report the Super release, and that one fact shapes everything else
here.** A `--release` binding is armed when its own key goes _down_ and is
discarded by the next key press, so the release that follows a Tab is never
seen. Measured against a nested sway driven by wtype: pressing `b` and releasing
it fires `--release b`; pressing `b`, then `a`, then releasing `b` fires
nothing; neither does releasing `b` after an intervening press _and release_, or
after two of them, or when the intervening press changed the binding mode. A
release binding inside a mode does fire, but only for a key pressed after the
mode was entered — which Super never is. Global or mode-local, with or without
the modifier in the combo, there is no binding that sees it, and sway's IPC
exposes no modifier state either (`get_inputs` carries the layout, not the
mods).

What _can_ see the release is whatever holds the keyboard, so the picker's own
layer surface takes it as an ordinary `Qt.Key_Meta` release. That is why the
sway side is a **mode that binds almost nothing**: `$mod+Tab` enters `$cycle`
and hands over, so every later Tab reaches the surface instead of a binding
here, and every other `$mod` combo is inert while the picker is up. Measured:
with the surface focused inside the mode, sway consumed the first Tab as its
binding and delivered the second, along with `$mod+Left`, whose global binding
correctly did not fire. The shell returns sway to the default mode itself
(`I3.dispatch("mode default")`) on every path out — commit, cancel, Escape,
click-outside, and the early return when there are fewer than two windows. The
mode binds `Escape` and `$mod+Escape` and nothing else, as the way out if the
shell never takes the keyboard, which is the only way the mode can be left
holding it.

So the surface maps when the _gesture starts_, not when it is first drawn — it
has to, to be focused in time for the release — and `ModalOverlay` grew a
`drawn` property for the gap: no card, no scrim, and an empty input `mask` so it
cannot swallow a pointer event meant for what is beneath it.
`WindowService.revealDelay` (180ms) is what separates a tap from a hold, and a
second Tab reveals immediately, since by then the user is steering the picker
rather than tapping through it.

One race is inherent and worth knowing before chasing it: the release is only
delivered once the surface is _focused_. Measured end to end,
`quickshell ipc call` costs ~40ms and the surface was keyboard-focused 8ms after
the handler ran, so the release is catchable from ~45ms after the keypress; a
release before that lands in the app instead and leaves the picker open, which
Escape or a click outside clears. A tap cannot release Super before it has
released Tab, so the margin holds in practice. Verified from the other end too:
a surface mapped 1.5s _into_ a hold still received the release, so the client
need not have seen the press.

Thumbnails are `grim -T <foreign_toplevel_identifier>`, the same three-way match
the screencast chooser turns on (`.local/bin/window-thumbs`, one `Process` whose
stdout is read progressively). A 15-window batch costs ~470-590ms and **the size
does not matter** — 240, 480, 960, 1280 and 1600px measured at 562, 468, 485,
476 and 509ms — so the cost is the per-window capture round trip and not the
scaling or the encode, and they necessarily fill in _after_ the card appears.
Being generous is therefore free, and the captures are sized for the picker's
preview box in **physical** pixels: 1280, against a box that is 1062px on the
ultrawide and ~1134 on a 1920-logical laptop at scale 2. The two matter
separately — `Image.sourceSize` is in _logical_ pixels and Qt does not scale it
by the screen's ratio, so a box measured in logical units alone decodes at half
resolution on a scaled screen and looks soft, while a capture narrower than the
box is upscaled and looks it. Both images in a cell must carry the _same_
`sourceSize`, or they miss each other in the pixmap cache and the handover below
decodes from disk all over again. At that size 15 thumbnails are ~3.2MB of
tmpfs, and the shell's RSS rises ~70MB with the picker's decoded previews and
comes back down — measured flat across six consecutive cycles, so the cache is
bounded. Windows are handed over in MRU order so the cells being looked at
arrive first, and one capture per run is typically refused outright ("Invalid
stride", and which client it hits moves between runs), which is what the
app-icon fallback is for. The files live in `$XDG_RUNTIME_DIR/window-thumbs`
(0700 — they are pictures of the user's windows) and every cached one is
reported back before anything is captured, so a second cycle draws the previous
picture of each window at ~19ms and replaces it as the fresh captures land; an
identifier nobody asks about any more is pruned, which is how a closed window
loses its thumbnail. A capture that is refused keeps whatever picture it last
managed, which can be an old one.

**The batch has to outlive the gesture**, and this is the one to know, because
getting it wrong looks like the cache never working at all. A tap or a short
hold is over in a few hundred milliseconds, so killing the process when the
cycle ends truncated the batch at whatever had finished: the windows that
capture last were recaptured and killed on every cycle, so they were stuck on
the first picture ever taken of them, hours stale, while the fast ones stayed
current. Measured — after a 350ms cycle, files from two hours earlier sat beside
files from that second. It is left running now, and a cycle that starts while a
batch is still in flight leaves it alone rather than restarting it.

The cell draws through **two Images, not one**: `pending` loads the incoming
capture out of sight and hands it to the visible one only when it is ready,
which then takes it from the pixmap cache and so never passes through a
`Loading` frame. Without that, every cell blanked while its refreshed capture
decoded and the fallback icon showed through — an icon flashing over each
picture on every cycle. The rule the fallback follows is that the icon means
"there is no picture of this window", never "the picture has not decoded yet",
so it is hidden while `pending` is loading.

The picker is **one row that slides under a fixed centre**, not a grid the
selection moves around inside. The card is centred on the screen and 94% of its
width; the strip is a horizontal `ListView` whose highlight range is pinned to
the middle of the view with `StrictlyEnforceRange`, so the selected window is
always in the centre of the screen — including at either end of the list, where
the space beside it is simply empty. Moving the selection is what animates: with
`highlightMoveVelocity: -1` the enforced range brings the new item to the centre
over `highlightMoveDuration` regardless of how far it travelled, measured
offscreen as `contentX` sliding -350 → 650 and settling within 180ms. The cell
is sized from the screen's _height_ (55% of it) and then capped so at least
three windows fit across, since a cell wide enough to hide its neighbours has
nothing to slide; on the ultrawide that is ~1090px wide and ~790 tall. The
preview box inside it is **3:2 rather than 16:9**: what goes in it is a window,
and tiled thirds and halves of an ultrawide are nearer square than a screen is,
so a wider box letterboxes every one of them. There is deliberately **no hover
selection** — selecting recentres the strip, so the hovered cell would slide out
from under the pointer and hand it the next one, which would do it again;
clicking a cell still picks that window. The wheel moves the selection, clamped
rather than wrapped as Tab is, since a wheel that rolls off the end of a list
stops there.

**A `WheelHandler` does not work here and a `MouseArea` does**, which is worth
knowing because the handler is the modern spelling and fails silently. One on
the Item wrapping the `ListView` never fired once against a virtual pointer,
while a `MouseArea` filling the same area saw every event; both were
instrumented in the same build and scrolled in the same run, so it is not a
question of which was tried. It carries `acceptedButtons: Qt.NoButton`, which is
what lets a press through to the cell underneath so clicking still picks a
window — verified after the change, not assumed.

`wlrctl` is what drives a pointer here (`wlrctl pointer move` is relative, so
the cursor is slammed into a corner first and then moved to a known point;
`wlrctl pointer scroll <dy> <dx>`). Its scroll value arrives in Qt as
`angleDelta` **×12** — measured, 15 came through as 180 — so **10 is one
120-unit notch**, which is what a test should send. That factor is an artefact
of the virtual pointer rather than of the wheel: a physical wheel reaches Qt
through `wl_pointer.axis_value120` and lands on 120 exactly. Verified end to end
this way: one notch down moves one window towards the next, three move three, up
moves back, scrolling past the start clamps rather than wrapping, and the thumb
wheel's horizontal axis does the same as the vertical one.

The MX Master's thumb button opens and closes the picker
(`quickshell ipc call windows cycle`, which draws it at once since there is no
modifier to hold, and commits on the next press the way releasing Super does).
**That button emits no mouse button at all** — it sends the keys
**Ctrl+Alt+Tab**, which is why it appeared to do nothing and why probing
`BTN_TASK` and its neighbours found nothing. `/proc/bus/input/devices` is the
tell: the mouse carries a `kbd` handler and `EV_REP` alongside `mouse0`, so it
is a keyboard as well.

Finding it needed no root, and the technique generalises: **a sway binding can
be scoped to one device** with `--input-device=<identifier>`, so
`bindcode --input-device=<mouse> <code> exec …` for every keycode 8-255 catches
whatever a device sends while leaving the real keyboard untouched. Bare keycodes
catch only the first key of a combination — once a modifier is held a probe has
to name it — so a second pass over `Ctrl+<code>`, `Ctrl+Alt+<code>` and so on is
what completes the sequence. Here that was keycode 37, then 64, then 23: Ctrl,
Alt, Tab. The binding stays scoped to the mouse by identifier, so the same combo
from a keyboard is left alone.

**A binding that switches modes has its own key press re-matched in the new
mode.** The thumb button was first bound in both modes, the way $mod+Tab is —
and a single press fired _both_, opening the picker and immediately closing it
again; instrumented, one synthetic press wrote both bindings' log lines. So the
thumb binding does not switch modes at all: one binding that stays live in the
default mode is what lets the second press reach it, and nothing is lost, since
the picker holds the keyboard itself and Tab and Escape are unbound in the
default mode. Note also that **sway's mouse-button bindings do not reach layer
surfaces** — a `--whole-window` `BTN_EXTRA` binding fired over an ordinary
window and not over the open picker — so a mouse button could never have closed
it from sway's side either.

Testing this without a keyboard is possible from both ends:
`quickshell ipc call windows next` is exactly what sway's binding does, and
`wtype -P Super_L -p Super_L` sends the real key events that commit it
(`-M logo` only sets the modifier _mask_ and sends no key at all, which is why
it can never exercise this path). Note that a **runtime `mode "X" { … }` over
IPC is a parse error that still creates the mode** — empty, with no bindings —
so a session set up that way enters a mode with no Escape in it; only a
`swaymsg reload` gives the mode the config file describes.

`StdioCollector`'s **`data` is a byte array; the string is `text`.**
`JSON.parse(data)` happens to work because it coerces, so a `get_tree` collector
reads fine and a `data.split("\n")` on the next one throws
`Property 'split' ... is not a function` and silently leaves the list empty. Use
`text`.

Frecency lives in `Quickshell.statePath("launcher.json")` as
`{ id: { count, last } }`, weighted by recency bucket (<1d ×4, <7d ×2, <30d ×1,
older ×0.5). Desktop actions (`entry.actions`) appear as indented sub-rows, but
only once there is a query — with none they would pad the list with rows nobody
asked for, which is why wofi hid them outright (`no_actions=true`). Run mode
lists every executable on `PATH` and falls back to running the typed line
verbatim, so a command with arguments still works.

**Suspend and Hibernate are gated on what logind says it can do**, asked at
startup with one `busctl` loop over `CanSuspend`, `CanHibernate` and
`CanSuspendThenHibernate` — they are methods, not properties, so
`busctl get-property` cannot read them. Suspend dispatches
`systemctl suspend-then-hibernate` where that is offered and plain
`systemctl suspend` where it is not, and Hibernate is dropped from the list
entirely rather than shown and refused. It used to hardcode
`suspend-then-hibernate` and `hibernate`, both of which logind refuses on a
Secure Boot machine: `lockdown=integrity` disables hibernation, so
`/sys/power/disk` reads `[disabled]`, `/sys/power/state` offers only
`freeze mem`, and both capabilities read `na` — while swap and a `resume=` in
the initramfs are still present, so everything _looks_ ready. The probe is
per-host because the two machines need not agree and the answer changes with
Secure Boot; the property defaults are the conservative reading, so a menu
opened before it lands offers plain suspend and no hibernate. `"challenge"`
counts as available, since it only means logind will ask polkit and quickshell
is the agent. Verified three ways on this host: as measured, Suspend alone
mapping to `systemctl suspend`; with hibernation forced available,
`suspend-then-hibernate` plus a Hibernate row; with nothing available, both
gone.

"Reload Sway" and "Restart Quickshell" sit between Lock and Log Out. Sway has no
restart-in-place, so the first is `swaymsg reload` — which is lockup trigger #1,
and which `theme` no longer needs now that it applies colours with targeted
`swaymsg client.*` commands, so it is in the menu because it is asked for by
hand and not because anything else uses it. Neither confirms: both are
recoverable, and a countdown in front of restarting the bar is ceremony.
Restarting quickshell from inside quickshell works because the action is
dispatched as a sway `exec`, so the `systemctl` client lives in sway's scope
rather than the unit being restarted. `windows/CountdownDialog` inverts what
zenity did: its `countdown` (seconds, `PowerService.confirmSeconds`, one value
for every action) ticks down and fires `accepted` at zero, so waiting confirms
rather than cancels and the dialog is an announcement with an escape hatch, not
a question. That is also why the actions carry a `confirm` flag rather than a
question string — "Are you sure you want to reboot?" above "Reboot in 8 seconds"
asks something the dialog then answers itself. The **accept** button holds
focus, not Cancel — picking an action in the menu and pressing Return again goes
straight through, which is the point of a dialog that was going to proceed
anyway. That in turn is why `widgets/Button` ignores `event.isAutoRepeat`: the
dialog opens under a Return that may still be held, and at sway's default 600ms
repeat delay the repeat would otherwise land on the freshly focused button and
skip the countdown entirely. The menu closes before anything is dispatched, so a
polkit prompt never contends with it for exclusive keyboard focus. The countdown
is `modules/power/PowerConfirm.qml`, instantiated once in `shell.qml` rather
than per bar as the menu is: it is a modal on the focused output, and the action
it announces is not tied to the bar the menu was opened from.

`services/{AudioService,BrightnessService,OsdService}` + `modules/osd/Osd.qml`
replace `.local/bin/volume` and `.local/bin/brightness`, and with them the
notify-send-as-OSD pattern that used to put every volume keypress into
notification history. Sway calls them on the media keys —
`quickshell ipc call audio up|down|mute|micMute` and `brightness up|down`.
pamixer and brightnessctl are left installed but unreferenced.

There is **one** OSD surface, not one per source: `OsdService` holds only
`active` and a `source` name plus the 2s timer, and `Osd.qml` owns the three
descriptors, so a volume keypress and a brightness keypress a moment apart
replace each other rather than stack. It sits bottom **centre**, out of the way
of everything anchored to the bar, and is click-through via `mask: Region {}` —
an overlay layer surface otherwise swallows every pointer event in its geometry
for its whole lifetime.

**A QML singleton is created when it is first referenced.** A service reached
only over IPC therefore never registers its `IpcHandler` — `AudioService` and
`BrightnessService` instantiated nowhere loaded clean and did nothing, with
`quickshell ipc show` listing neither target. Referencing them inside a
conditional is not enough either, since JS short-circuits; `Osd.qml`'s three
descriptors are unconditional bindings, evaluated at completion, and that is
what brings both services to life. Anything IPC-only in future needs the same.

`AudioService` reads Pipewire, and two things about it:
`Pipewire.defaultAudioSink` is **null at `Component.onCompleted`** (`ready`
false), so every read is `?.`-guarded; and without the `PwObjectTracker` a node
reports its defaults rather than real values. `PwNodeAudio.volume` (0..1) is the
same scale pamixer printed, so the 0.05 step is exactly the old `pamixer -i 5`.
Up and down unmute first, as the script did.

`BrightnessService` writes `/sys/class/backlight/*/brightness` directly — it is
`root:video 0664` and the user is in `video`, so no brightnessctl. The write
needs **`atomicWrites: false`**: FileView's default write-to-temp-then-rename is
refused by sysfs. `watchChanges` + `onFileChanged: reload()` is what picks up
the firmware's own hotkeys, and `onSaveFailed: reload()` is what stops the
optimistic `level` in `set()` from lying when a write is refused — a refused
write leaves the file unchanged, so nothing else would correct it. The device is
discovered asynchronously by a one-shot `ls -1 /sys/class/backlight | head -1`,
which works because **a `FileView` with `path: ""` is silent** (no load, no
error); until `max_brightness` loads, `available` is false and the keybinds do
nothing. The step is brightnessctl's `10%` of the full range, and the floor is
one raw unit rather than zero, deliberately: a panel at zero is
indistinguishable from a session that has died.

`widgets/LevelBar` is the read-only fill bar both the OSD and
`NotificationCard`'s `-h int:value:` progress draw; `widgets/Slider` is the same
bar with a grab, and the caller keeps `value` bound to its own state and writes
through the `moved` signal so the binding is never broken.

`modules/bar/Volume.qml` + `modules/audio/AudioPanel.qml` replace **pasystray**
(`config:85`, gone). The bar item is icon + percentage — click toggles the
panel, middle-click mutes, wheel adjusts without the OSD, since the number the
OSD would show is already on the bar. The panel is output and input level rows,
the two device lists, per-app stream volumes, and an "advanced…" link to
`pavucontrol` for everything Pipewire exposes that this does not (routing,
profiles, moving one app to another device) — which is why the `pavucontrol`
floating rule stays.

`services/BluetoothService.qml` + `modules/bar/Bluetooth.qml` +
`modules/bluetooth/BluetoothPanel.qml` replace **blueman-applet** (`config:86`,
gone, along with the dead `blueman-services` / `blueman-sendto` window rules;
its XDG autostart entry is shadowed, see Autostart). The panel is adapter power,
then the paired devices — click to connect or disconnect, hover for a forget
`x`, battery percentage where BlueZ offers one. `Quickshell.Bluetooth` reports a
freedesktop icon name per device class (`audio-headset`, `input-mouse`, `phone`,
…) which `deviceIcons` maps onto vendored Phosphor icons, falling back to
`bluetooth`.

**Quickshell 0.3.0 registers no `org.bluez.Agent1`** — the binary carries
`Adapter1`, `Device1` and `Battery1` and nothing else — so it cannot answer a
PIN or a confirmation and `pair()` is unreliable by construction. That alone
keeps **pairing and discovery out** of the panel; a second reason, that a scan
list could not refresh inside a size-locked popup, no longer applies now that
`BarPopup` is a layer surface. "advanced…" launches `blueman-manager`; that
D-Bus-activates `blueman-applet` (`SystemdService=blueman-applet.service`),
which _is_ the agent, and both exit when the window closes — verified by killing
every blueman process, opening the panel's link, and watching the applet
reappear under `user@1000.service` and then go away again. No tray icon comes
back with it, so nothing duplicates the bar item.

The device list is sorted **by label alone**, never connected-first: sorting by
state means clicking a device reorders the list under the cursor, sliding the
next row — and the forget `x` that appears on hover — under the pointer. Same
reasoning as the audio panel's device lists, one degree worse because here the
click is what triggers the move.

`services/NetworkService.qml` + `modules/bar/Network.qml` +
`modules/network/NetworkPanel.qml` cover the part of **nm-applet**'s menu that
got used: the wifi radio, the access points in range, the wired link, and the
saved VPNs, with "advanced…" launching `nm-connection-editor`. The bar item is
the signal-strength icon plus a green `shield-check` badge whenever a VPN is up.

**nm-applet itself keeps running**, now from
`/etc/xdg/autostart/nm-applet.desktop` rather than a sway `exec` (see
Autostart). It is NetworkManager's _secret agent_, and Quickshell registers none
— the binary has zero `SecretAgent` strings — so without it an 802.1x network
fails silently and the `Lytx` openconnect VPN cannot connect at all, its cookie,
gateway and cert secrets all carrying `flags = 2` (never saved, ask the agent
every time). Unlike blueman-applet it has **no D-Bus service file**, so it
cannot be summoned on demand the way `blueman-manager` summons the BlueZ agent;
it has to be resident. Verified standalone: killing it and starting
`app-nm\x2dapplet@autostart.service` alone leaves it running and active. What
changes is only that `Tray.qml` now filters its item out by `id` (`"nm-applet"`,
read off its SNI `Id` property) so the bar does not show two network indicators.
That `hidden` list is the place to drop any other applet kept alive purely for a
D-Bus role.

`scannerEnabled` is off until the panel opens, and the list then goes from 1
entry to all of them over about five seconds. It fills a fixed-height `ListView`
(`listRows` × `rowHeight`) that scrolls: originally because a popup could not
resize, now because a list that grows under a stationary cursor moves the row
you were about to click. Same reason `FilterList` has `fixedHeight`. The
password prompt for an unknown WPA network replaces that list inside the same
box rather than being appended below it: the card is free to grow, but growing
it would shift the rows at the moment one was clicked. Escape is handled on the
prompt itself so it puts the list back instead of bubbling to the card and
closing the whole panel.

Access points are sorted **by name alone**, the 8b rule one degree stronger
again: signal strength moves on its own every few seconds, so sorting by it
slides rows under a stationary cursor with no click involved at all.

Quickshell 0.3.0's `Networking` has no VPN concept, so that half is nmcli:
`nmcli monitor` as the change signal, debounced 200ms into a one-shot
`nmcli -t -f NAME,UUID,TYPE,STATE connection show`, filtered to `vpn` and
`wireguard`. `-t` escapes a literal colon in a field as `\:` and only the name
can contain one, so the fixed trailing fields are split off the **right**.
Verified end to end against a throwaway wireguard connection: adding and
removing it moved the panel's list live, an external `nmcli up` lit the row and
the bar badge, and clicking the row brought it back down.

Two things about `Quickshell.Networking`, both established by spike:

- **The model starts loading on the first read and fills in asynchronously**,
  exactly as `DesktopEntries` does. Read at `Component.onCompleted` it reports
  `devices: 0`, `wifiEnabled: false` and `connectivity: Unknown`, and is only
  right a second or two later — so every value is a binding and `Network.qml` in
  the bar is what warms it at startup.
- **`networks` holds only the connected AP until `scannerEnabled` is set**, so
  the visible-network list does not exist until something asks for it.

**A signal handler written at the instantiation site replaces the component's
own**, it does not run alongside it: an `onVisibleChanged` next to
`NetworkPanel { … }` in the bar silently overrode the one in `NetworkPanel.qml`,
which is why the scan toggle lives in the panel with the prompt reset it shares
a handler with.

`windows/BarPopup` is the chrome behind all three panels: children stack in a
column and the card sizes to them. It is a `ModalOverlay` with an `anchorItem` —
an overlay layer surface hung under a bar item — and **not** a `PopupWindow`,
which is the single most important thing about it.

It sets `ModalOverlay`'s `attached` mode, which is what makes it read as the bar
itself expanding rather than as a box floating under it: the card's top edge is
unstroked and its top corners curve the _other_ way, flaring `flare` px past
each side so the card's walls grow out of the bar's bottom edge. `cardColor` is
`Theme.barBackground` rather than `popupBackground` for the same reason — a
mantle card under a base bar draws a horizontal seam exactly at the join, which
is the one line the whole treatment exists to erase. The outline is
`widgets/AttachedOutline`, a `Shape` — a concave corner needs real transparency
in the notch, so it cannot be faked with a `Rectangle` and an overlay — and the
notification stack draws with it too. The flare overflows the card, so the clip
that hides the content during the roll-down sits on an inner `Item`, never on
the card; and an anchored card is clamped to keep `flare` px of screen on either
side. Opening and closing animate the card's height, which means the surface has
to stay mapped through the collapse — hence `expanded` as the state a bar item
toggles and `visible: expanded || cardHeight > 0`. It has to be the card's
height and not the animation's `running`: `visible` and `revealed` both
re-evaluate off `expanded`, and if `visible` goes first the Behavior has not
started yet, so `running` reads false and the surface unmaps for a frame in the
middle of the collapse. `cardHeight` is still the full height at that instant
and only reaches zero once the card has rolled up, so the ordering cannot bite.
Anything that used to dismiss a panel with `root.visible = false` must set
`root.expanded = false` instead, or it breaks that binding for good. The same
`Behavior` also animates content-driven resizes, so the network panel's swap
between its list and its password prompt grows the card rather than jumping it.

**A `PopupWindow` can never hold keyboard focus.** It has only `grabFocus`,
which is the pointer grab; keys go to the _parent_ layer surface, which is a
different window, and Qt delivers key events only to the focused one. A text
field inside a popup therefore shows a caret and then never receives a
character, Escape never arrives, and — because sway will not honour the popup's
grab either — clicks outside it land in whatever is under the bar instead of
dismissing it. Measured with `Window.active`, calibrated against the launcher:
an open `ModalOverlay` reads `true`, an open `PopupWindow` reads `false` even
with its parent bar surface set to `Exclusive`. This is what the panels were
originally built on, and it is why the network password prompt could not be
typed into.

**`WlrLayershell.keyboardFocus` is applied when the layer surface is created and
ignored on every later change.** Setting the bar to `Exclusive` only while a
popup was open changed nothing (`kb=1`, still `active=false`); the same constant
set before startup made the bar active immediately. So a surface that wants the
keyboard _some_ of the time holds a constant `Exclusive` and toggles `visible` —
which destroys and recreates the surface — which is exactly what `ModalOverlay`
has always done and why the launcher works.

Two consequences worth keeping. A `PanelWindow` is **visible by default**, so a
dropdown must say `visible: false` or it maps at startup as a full-screen
overlay and silently swallows every click meant for the bar. And
`ModalOverlay`'s card holds `focus: true` itself, so Escape lands even with no
`focusItem`; where there is one, focus moves to that child and Escape still
bubbles back up.

Because the card is now an ordinary layer surface it may **resize freely while
open**, which an xdg_popup may not: `PopupWindow` takes its geometry when it
maps and never again (`implicitHeight` went 762 → 728 across a bluetooth scan
while `height` stayed 762, and `reposition()` does not re-send it). That
constraint is gone, so the bluetooth scan list kept out of `BluetoothPanel` for
this reason could come back, and the network list's fixed height is now a choice
rather than a requirement. Being an overlay, an open panel also covers the bar,
so a click anywhere outside the card — including on another bar item — dismisses
it rather than reaching what is beneath. `AptUpgrade` is on `BarPopup` too, at
`cardWidth: 560`; its package list keeps the 20-row cap the old fixed height
enforced, but as `Math.min(contentHeight, maxRows * rowHeight)` on the list
itself, so the card grows with the list rather than always standing at full
height. Its `Keys.onEscapePressed` had been dead code for as long as it was a
`PopupWindow`, and works now.

Three things about `Quickshell.Services.Pipewire`, each established by spike:

- **A node's `type` is readable untracked; its `audio` values are not.** An
  untracked node reports `volume: 0` and `ready: false` but its type flags are
  already right, so `AudioService`'s three lists filter on `type` (`AudioSink`
  17, `AudioSource` 9, `AudioOutStream` 21 — a playback stream is `isSink` _and_
  `isStream`) and the `PwObjectTracker` then tracks what they select. Filtering
  on `audio` instead is circular: the tracker would have nothing to track and
  the lists would stay empty for good.
- **`nodes.values` is registry order, and it is not stable.** A device that
  re-registers — an HDMI sink following a monitor — comes back at the end of the
  list, so the rows reshuffle under the cursor between opening the panel and
  clicking a row. Both device lists are sorted by label.
- **Writing `preferredDefaultAudioSink` is the whole of "set the default
  device"**; it lands in wireplumber's `default.configured.audio.sink`.
  WirePlumber may then decline it — an HDMI output with nothing plugged in stays
  refused, and `pactl set-default-sink` on the same node is refused identically
  — so the tick follows the _effective_ default rather than what was clicked,
  which is the honest reading.

`windows/Wallpaper.qml` is the desktop background, one layer surface per screen,
replacing swaybg. It reproduces swaybg's `center` mode exactly — the image at
its native size, centred and clipped, over `Theme.crust` — so `sourceSize` is
deliberately left unset: `center` means no scaling, and binding it to the screen
would silently start resampling. Two stacked `Image`s crossfade on a theme
switch, and **both ends animate**, because the wallpapers are not all the same
size (nord's is 1920×1080, the rest 3840×2160) and a smaller incoming image
would not cover the one it replaces. The fade starts on any `Image.status` that
is not `Loading`, so a theme naming no wallpaper (`Null`) or a missing file
(`Error`) still fades the old image out instead of stranding it.

**The layer is `WlrLayer.Bottom`, not `Background`** — which is where swaybg
itself sits. Sway draws same-layer surfaces in creation order and `theme set`
re-forks swaybg over IPC, so a `Background` surface ends up _under_ a
solid-colour swaybg started after the shell, and the wallpaper vanishes until
the next restart. Established by spike: with both on `Background`, re-running
`swaymsg output '*' bg <colour> solid_color` painted the whole screen that
colour; on `Bottom` the image survives, and windows still draw above it.
`mask: Region {}` keeps it click-through, as swaybg's empty input region was.

Wallpapers are PNGs in `wallpapers/`, named by the `wallpaper` key of each theme
JSON (carried into `themes.json` for the picker) and resolved against
`Paths.wallpapers`. **They carry no background of their own** — it is knocked
out to transparency, so `Wallpaper`'s `color: Theme.crust` fills both the
letterbox and the area behind the artwork and the two cannot disagree. They used
to: every Catppuccin wallpaper was painted against `#1e1e2e`, which is _Mocha's
`base`_ and not any theme's `crust`, so frappé, macchiato, mocha and latte all
drew a visibly different rectangle inside the letterbox. Knocking the background
out rather than repainting it to each crust keeps the image independent of the
palette, so it stays right if a crust ever changes or a new theme points at an
existing image.

The knock-out has to recover alpha, not just replace a colour: a colour replace
leaves every antialiased edge still blended against the old background. Treat
each pixel as `a*fg + (1-a)*bg` for the known flat `bg` and take the smallest
alpha that keeps `fg` in range — the standard unmatting solution — which
recomposites over the original background to within 1/255. Write the result
paletted when it fits in 256 colours, which four of the five do:
`cat-blue-eye.png` was already a PNG8 and saving it as truecolour RGBA tripled
it, while paletted output leaves the five within +7% in total.
`themes/unmat-wallpaper <in> <out> <#bg>` does all of it — it lives in `themes/`
with the palettes rather than in `.local/bin`, since like the templates it is
authoring input and is never symlinked into `$HOME`. Adding a wallpaper means
running it once with the image's own flat background colour. The picker previews
them, and **the crossfade is suppressed while it does** — `previewing` is
`Theme.previewWallpaper !== ""`, and a preview swap is instant. The colours
preview instantly and cannot be animated in step, so a fading wallpaper lags the
highlighted row — arrowing faster than the fade leaves the previous theme's
artwork ghosting under the current one, a step behind the selection. The rule
that falls out is that **the crossfade is for changes nobody watched happen** —
committing from the picker is instant because you already saw it, and a
`theme set` from a terminal fades. Decoding is not the constraint it looks like:
a cold 3840×2160 PNG is 13-43ms and a re-visited one costs nothing at all, since
a cached image produces no `Image.status` transition. `sway.conf.tmpl` ends at
`output * bg $background solid_color`, which overrides the Debian default in
`/etc/sway/config.d/40-sway-background.conf` and is what shows during a shell
restart.

`quickshell ipc call` costs ~31ms a call, against sway's default 40ms key
repeat, so holding a volume key keeps up without a long-lived socket.

`services/MprisService.qml` + `modules/bar/Media.qml` +
`modules/media/MediaPanel.qml` replace **playerctl** (`config:289-291`, now
`quickshell ipc call media playPause|next|previous`). The bar item is the track,
in the **centre** section immediately right of the clock, and it must hang off
the clock rather than sit in a row with it: its width changes on every song, so
a row would walk the clock off centre each time one ended, and the right section
— being anchored to the right edge — would shift every icon along it instead.
The panel is art, the track, a seek bar, the transport, and — only once there is
more than one — the players to choose between.

Four things about `Quickshell.Services.Mpris`, each established by spike:

- **`Mpris.players` starts empty and fills in asynchronously**, exactly as
  `DesktopEntries` and `Networking` do, so every value is a binding and the bar
  item is what warms the singleton.
- **A binding over `players.values` re-evaluates only when a player appears or
  disappears**, never when one of them starts playing or changes track.
  `MprisService` therefore rebuilds its list by hand from an `Instantiator`
  whose model is `Mpris.players` — the model, _not_ `.values` — so one watcher
  is created per player and survives every state change. `refresh()` compares
  before assigning, or a title change would hand every list a fresh array and
  rebuild its rows.
- **Most players on the bus are not media.** Chrome keeps a stopped, untitled,
  uncontrollable instance up whenever it is running, and kdeconnect publishes
  one per remote app whether or not that app has any;
  `canControl && (canTogglePlaying || trackTitle !== "")` is what leaves the
  real ones. `activeName` records the last player known to be playing, on the
  transition **and** on appearance — a player already playing when it appears
  emits no `isPlayingChanged`, and without that the first track of a session
  leaves the fallback picking a kdeconnect mirror.
- **`position` extrapolates on read**, advancing 1.00s per second between
  fetches, so the panel's 1s poll is a local read rather than a bus round trip.
  Writing it seeks.

`modules/calendar/CalendarPopup.qml` is a `BarPopup` under the clock, a
hand-rolled 7×6 grid from `Date` rather than `QtQuick.Controls`. It takes today
from the bar's own `SystemClock`, so the highlight moves at midnight with no
second timer. The grid is **always six rows**, even for the months that fit in
five: one that changed height would move the card's own edges as you page
through it. The month name is the way back to today, which is otherwise several
presses away once you have paged into next year.

`services/EmojiService.qml` + `modules/emoji/EmojiPicker.qml` replace **bemoji**
(`config:308`, now `quickshell ipc call emoji toggle`); `wtype` stays, because
picking still copies and then pastes. The `<glyph> <name>` database bemoji
downloaded is **vendored** at `.config/quickshell/emoji.txt`, for the same
reason the Phosphor icons are. Frecency is the launcher's shape exactly, in
`statePath("emoji.json")`. bemoji is not tracked here — it is a loose script in
`~/.local/bin` — so it is left on disk unused, as wofi and zenity were.

**A clipboard write only takes the Wayland selection when it happens inside an
input event handler.** `Quickshell.clipboardText` is writable and the value
always reads back, but Qt takes the selection using the seat's last input
serial: a write from a timer updates Qt's own copy and nothing else, and
`wl-paste` goes on reporting the old contents. Measured four ways — no surface
(fails), focused overlay + timer (fails, with `Window.active` reading **true**,
so it is not a focus problem), focused overlay + key handler (works), and the
same followed by hiding the surface (works, and keeps working). Ownership then
lasts as long as the shell _process_, surviving the picker closing indefinitely,
which is one fewer forked helper than `wl-copy` needed. So `copy()` and
`paste()` both run straight from the row's activation handler. Paste is
dispatched through sway rather than run as a `Process`, for the same reason the
launcher dispatches `exec`, and carries a 100ms sleep the old binding did not
need: the overlay is still unmapping when the handler returns, and the keystroke
has to land in the window the picker was covering. Testing a paste against a
**terminal** proves nothing — alacritty's paste is Ctrl+Shift+V and Ctrl+V is
quoted-insert; use a GUI field.

`modules/polkit/PolkitDialog.qml` is the session's polkit authentication agent,
replacing `polkit-kde-authentication-agent-1`. It is instantiated once in
`shell.qml` (not per screen) and draws a modal dialog on an overlay layer
surface with exclusive keyboard focus, on whichever output holds the focused
sway workspace. Quickshell's `PolkitAgent` registers on startup, so nothing in
the sway config launches an agent. Quickshell does not forward PAM's own failure
text — it only logs "Unknown line ... from helper" — so a rejected password is
reported from `AuthFlow`'s `authenticationFailed` signal instead.

`lock.qml` is the session lock, and it is deliberately a **second process** with
its own unit (`quickshell-lock.service`, started on demand by `.local/bin/lock`,
never part of the session target). If the shell held the `WlSessionLock` and
crashed, sway would keep the session locked — the protocol's guarantee — and
leave a black screen with nothing to type into; isolating it means every bar
edit and `systemctl --user restart quickshell` is lock-safe — **the process is,
the config watcher is not**. `lock.qml` is rooted at the same
`~/.config/quickshell` tree, so it _would_ hot-reload with the shell — and a
reload while locked re-creates a lock surface on an output that already has one,
which is the fatal `ext_session_lock_v1` error 3 `duplicate_output`. That
happened on 2026-09-05 and only `Restart=on-failure` recovered it, a second
later. The unit therefore sets **`QS_DISABLE_FILE_WATCHER=1`**, which is the
only lever for this — there is no CLI flag — and was A/B'd: editing the loaded
file reloads the process without it and does not with it. Editing QML while the
screen is locked is safe again. `services/LockService.qml` owns the `PamContext`
(`config: "swaylock"`, which on Debian is `@include common-auth`) and
`modules/lock/LockSurface.qml` is the per-screen view, instantiated by
`WlSessionLockSurface` for a real lock and by one overlay `PanelWindow` under
`QS_LOCK_DEMO` — demo mode is where all layout work happens, since Escape always
closes it.

**`Quickshell.env()` returns `null` for an unset variable, not `""`.**
`env("QS_LOCK_DEMO") !== ""` is therefore true when the variable is _unset_,
which silently put every real lock into demo mode and drew an escapable overlay
instead of locking. It is `!!env(…)` now; anything reading an optional env var
wants truthiness, not a comparison against `""`.

**`WlSessionLock.secure` is the "surfaces are up" signal.** `LockService` writes
`$XDG_RUNTIME_DIR/quickshell-lock.stamp` on it and `lock` polls for that before
returning, so `before-sleep` cannot suspend over a half-mapped surface; `lock`
removes the stamp _before_ starting the unit, which is what makes waiting for it
meaningful. If nothing maps within 2s it falls back to `swaylock -f`, which is
why swaylock and `swaylock.conf.tmpl` stay installed. **sway accepts a
replacement lock client for an abandoned lock** — `SIGKILL` while locked leaves
the session locked, and a fresh client maps and re-confirms `secure`
(re-confirmed 2026-09-07 from sway's own `session lock abandoned` /
`Replacing abandoned lock` log; a _live_ lock instead refuses the second client
with `finished()`). **`SIGTERM` abandons it too**, which is why
`systemctl --user stop` — swayidle's `unlock` hook, and so what
`loginctl unlock-session` reaches — used to leave a locked screen with no client
attached. The unit now carries an `ExecStop` that calls
`quickshell -p …/lock.qml ipc call lock unlock`, dropping `LockService.locked`
so the client sends `unlock_and_destroy` and exits before any signal is sent;
`TimeoutStopSec=5` keeps the SIGTERM fallback quick. The trade is that any
same-uid process can now unlock without the password — the authority logind
already assumes for `loginctl unlock-session`. `Restart=on-failure` is still
real crash recovery, and from a VT
`systemctl --user start quickshell-lock.service` is the way back to a prompt.
The unit sets `StartLimitIntervalSec=0` deliberately: a unit that gives up
restarting leaves a locked session nobody can type into.

`LockService` also calls logind's **`SetLockedHint`** — true on `secure`, false
when `locked` drops — so `LockedHint` follows reality whichever path locked the
session. Nothing consumes it yet; it is set so that anything added later which
asks logind whether the session is locked is not told "no" with the lock screen
up. Two things about it, both measured. `/org/freedesktop/login1/session/auto`
is the right object even though the lock runs as a user unit with no session of
its own and no `XDG_SESSION_ID` in its environment — logind falls back to the
user's display session, resolving to the same session id there as from a login
shell, and the write needs no polkit. And it is `Quickshell.execDetached`, not a
`Process`, because the client quits 250ms after unlocking and would tear a
`Process` down with it. A killed client leaves the hint set, which is correct:
the compositor goes on holding an abandoned lock, so the session really is still
locked. The clear is guarded on having set it, so demo mode — which never goes
`secure` — cannot report an unlock that never happened.

**swayidle owns idle policy and the shell only draws** (`swayidle.service`, see
Session services). It holds every timeout — dim at 240s, lock at 300s,
`output '*' power off` at 600s — alongside the logind
Lock/Unlock/PrepareForSleep hooks it always had, because it is the one thing
here that can hear those at all. `services/IdleService.qml` is therefore nothing
but a `dimmed` flag and an `IpcHandler`: `quickshell ipc call idle dim` /
`undim`, drawn by `modules/idle/IdleDim.qml` (click-through, so the input that
dismisses it still reaches the window underneath). That binding on `dimmed` is
also what _warms_ the singleton — an IPC-only service is never created and never
registers its handler, so do not make it conditional.

This is the opposite of what a 2026-09-07 review recommended, and the trade is
recorded in `.claude/idle-lock-audit.md`: quickshell could bound a leaked
inhibitor with `respectInhibitors: false` and swayidle structurally cannot,
binding `ext_idle_notifier_v1` at version 1. There is deliberately **no
ceiling** on inhibitor-held idle — a 30-minute one would lock during any film,
since `wayland-pipewire-idle-inhibit` holds an inhibitor whenever audio plays —
and the bar's coffee cup is the answer instead. The cost of the single mechanism
is that swayidle is now the single point of failure for all four lock paths,
which is why its unit is `Restart=always` with **no start limit**.

Screen-off is a **real modeset** again: DPMS was re-tested on the laptop, whose
Intel CRTC failure was the reason for the paint-only policy, and is not a
problem there. `LockService.blankSeconds` and the black rectangle in
`LockSurface.qml` are gone with it, so `timeout 600` is the only blanking. The
unit's `ExecStartPre` powers outputs back on if any are off, guarded on
`get_outputs`' `power` field so an ordinary start issues no modeset: a swayidle
restarted while blanked starts un-idle, never fires the resume, and would
otherwise strand a black screen.

**Both kinds of inhibitor now reach the dim and the lock, and neither needs a
special case.** swayidle respects Wayland idle inhibitors compositor-side, and —
measured from its own strings (`Disable idle timeouts`,
`Not enabling timeouts: idle inhibitor found`) — disables _every_ timeout while
a logind idle inhibitor is held. So `.local/bin/noidle` and `InsomniaService`'s
third mode inhibit idle for real, where under the old quickshell-owned policy
only their `sleep` half ever did anything. `IdleService`'s side-door read of
`InsomniaService.mode.inhibitIdle` is gone, and so is `Bar.qml`'s
`IdleInhibitor`, which sat on a layer surface and so had never inhibited
anything. Note the hooks are unaffected by any of this: `lock`, `unlock` and
`before-sleep` are D-Bus signal handlers, not timeouts, so an inhibitor cannot
suppress a lock that was asked for.

Testing a real lock without risking the desktop means a **nested sway**
(`sway -c <minimal>` as a window in the session). One trap: the nested
compositor's IPC socket is usually found by mtime, and when that sway exits the
lookup falls through to the **real** session's socket — so the next
`swaymsg exec` locks the desktop you were protecting. Bind the socket once and
assert the nested compositor is still alive before each call.
