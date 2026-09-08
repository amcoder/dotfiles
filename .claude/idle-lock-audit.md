# Idle, dim, lock and unlock — audit (2026-09-07)

Host: **demise** (RTX 4080 SUPER, single DP-2 output, Odyssey G9). sway 1.12
(packaged), quickshell 0.3.0, session started by uwsm.

Status: **implemented 2026-09-08 and manually tested green.** The findings below
are kept as the record of how the chain was found; the design that replaced them
is in "The design, as built", with measured and untested claims marked as such.
The original header read:

Status: **read-only audit, nothing changed.** Reviewed 2026-09-07 by a second
pass with no shared context, then re-measured. Net result: **finding 2 was wrong
and is replaced by the opposite defect, finding 6 was wrong and is corrected,
part of finding 3 is withdrawn while the rest re-ran clean, and the proposed
design has open objections.** Findings 1, 4, 5 and 7 survived unchanged, and
review added finding 2b — a QML edit while locked can kill the lock client,
which is the most actionable defect in the document. Action items at the bottom.

## The chain

Four things happen on a fixed schedule after the last input event, and nothing
else ever happens:

```
    0s   last input
  120s   swayidle `idlehint 120` sets logind IdleHint=yes
  240s   IdleService.dimSeconds   → IdleDim paints 60% black, 1s fade, click-through
  300s   IdleService.lockSeconds  → Quickshell.execDetached(["lock"])
  +60s   LockService.blankSeconds → lock surface paints black
 never   DPMS, monitor standby, or automatic suspend
```

The constants are read from `IdleService.qml`, the swayidle line in
`.config/sway/config`, and `LockService.blankSeconds`. **They were not clocked
end to end** — see "What could not be measured".

## Findings, worst first

### 1. Suspend and Hibernate cannot work on this machine — BROKEN

`PowerService.qml` dispatches `systemctl suspend-then-hibernate` for **Suspend**
and `systemctl hibernate` for **Hibernate**. logind refuses both:

```
CanSuspend               yes
CanHibernate             na
CanSuspendThenHibernate  na
```

The cause is one level down. Secure Boot is enabled, which puts the kernel in
`lockdown=integrity`, which disables hibernation:
`/sys/power/disk` reads `[disabled]` and `/sys/power/state` offers only
`freeze mem`.

It *looks* ready and is not: there is 31.8G of swap and
`/etc/initramfs-tools/conf.d/resume` names it
(`/dev/mapper/demise--vg-swap_1`), so every artefact of a hibernate-capable
setup is present except the capability. Plain `systemctl suspend` would work and
is not offered by the menu.

The logind properties were read directly; the **refusal is derived from them,
not executed** — running the command to confirm would have suspended the machine
if the reading were wrong.

### 2. `loginctl unlock-session` abandons the lock instead of unlocking — BROKEN

**Settled 2026-09-07.** An earlier version of this finding claimed that killing
the lock client *unlocks* the session. That was **wrong**, twice over, and
CLAUDE.md's original claim was right. The real defect is the inverse.

Sway logs its own lock state, which needs no rendering and is not a pixel, so it
is the instrument this should have used from the start. One nested sway, one
cycle:

```
session locked                          ← client 1 takes the lock
session lock abandoned                  ← SIGKILL: the lock is KEPT
Replacing abandoned lock                ← client 2 takes over the abandoned lock
session locked
Cannot lock an already locked session   ← client 3 refused while client 2 is live
session lock abandoned                  ← SIGTERM: the lock is KEPT
```

Client 3 received `finished()` and not `locked()` — so the rule the original
experiment leaned on ("a compositor still holding a lock must answer
`finished()`") is true for a **live** lock, and the `locked()` that was observed
came from the *abandoned* path, which sway deliberately replaces. `WAYLAND_DEBUG`
also shows `unlock_and_destroy` is never sent under either signal.

The protocol says the same, and the text is on disk in
`wayland-protocols-*/protocols/staging/ext-session-lock/ext-session-lock-v1.xml`:
"If the client dies while the session is locked, the compositor **must not**
unlock the session in response", the compositor may "fall back to a solid color"
(which is the red that misled the first experiment), and it "may allow a new
client to create a `ext_session_lock_v1` object and take responsibility for
unlocking" (which is why the second-client control was powerless). It also
defines `invalid_destroy` — "attempted to destroy session lock while locked" —
so a SIGTERM'd `lock.qml` that never sets `LockService.locked = false` has **no
legal exit that unlocks**.

**The live bug:** swayidle's hook is
`unlock 'systemctl --user stop quickshell-lock.service'`, which sends SIGTERM,
which abandons the lock. So `loginctl unlock-session` leaves the session locked
with **no client attached** — a screen with nothing to type into — and
`Restart=on-failure` declines to restart after a clean stop. Recovery is
`systemctl --user start quickshell-lock.service`, which logs
`Replacing abandoned lock` and gives a password prompt back.

The fix is the `pkill -USR1 swaylock` idiom in QML form: handle SIGTERM in
`lock.qml` by setting `LockService.locked = false` so the client sends
`unlock_and_destroy` before exiting.

Two traps this cost, both recorded at the end of the document: **red is not a
safe "unlocked" marker** (sway paints an abandoned lock red), and **a `grim`
capture aimed at a nested compositor's window on the host output photographs the
host's lock screen** once the host is locked.

### 2b. A QML edit while locked can kill the lock client — BROKEN

*(Found last, by review; belongs here by severity rather than at the end.)*

`quickshell-lock.service` runs `quickshell -p ~/.config/quickshell/lock.qml`,
which roots its config at the **same tree the shell watches**. So the lock
client hot-reloads on any change under `~/.config/quickshell` — while the screen
is locked — and a reload re-creates the per-output `WlSessionLockSurface` on an
output that already has one. That is `ext_session_lock_v1` error 3,
`duplicate_output` ("given output already has a lock surface"), which is fatal.

This host's own journal already contains it, 2026-09-05, on real hardware:

```
00:29:57 quickshell[199520]:  INFO: Reloading configuration...     ← the LOCK process
00:29:57 quickshell[194507]:  INFO: Reloading configuration...     ← the shell
00:29:57 quickshell[199520]:  ext_session_lock_v1#37: error 3: session lock surface
                                already created for the given output
00:29:57 quickshell[199520]:  WARN: The Wayland connection experienced a fatal error
00:29:57 systemd: quickshell-lock.service: Main process exited, status=255/EXCEPTION
00:29:58 systemd: Started quickshell-lock.service
```

**CLAUDE.md's justification for the separate lock process is therefore only half
right.** It says isolating it means "every bar edit and
`systemctl --user restart quickshell` is lock-safe". The *process* is isolated;
the *config watcher* is not. Editing any QML while the screen is locked drops the
lock client, leaving an abandoned lock — a screen with nothing to type into —
for the `RestartSec=1` window plus quickshell's startup.

Two consequences:

- **`Restart=on-failure` is load-bearing in ordinary operation**, not merely for
  crashes. An earlier version of finding 2 called it "not the safety net it reads
  as"; the opposite is true, and this event is the proof.
- The fix is to stop the lock client watching the shell's tree — give `lock.qml`
  its own config root, or disable hot-reload in that process — rather than to
  make the reload idempotent.

Not reproduced deliberately: doing so means editing a QML file while the session
is locked, which risks stranding a locked screen, and the journal already
provides the natural experiment.

### 3. One Wayland inhibitor suspends the whole chain, with no ceiling — RISK

Both `IdleMonitor`s set `respectInhibitors: true`, so while any application idle
inhibitor sits on a **visible** window there is no dim and no lock — indefinitely,
silently, nothing logged. Chrome PWAs leak these and the Claude desktop app holds
one for the length of every turn.

~~The lock surface's own 60s blanking uses the same monitor, so locking by hand
while an inhibitor is held leaves the lock screen lit at full brightness.~~
**Wrong, withdrawn 2026-09-07.** It was flagged as derived rather than measured,
and the derivation does not hold: while a session lock is up, sway ignores every
application inhibitor that is not on the lock surface itself, so the 60s blank
proceeds regardless of what Chrome is holding. Nothing about the lock screen is
affected by a leaked inhibitor.

The bar's coffee-cup indicator (added 2026-09-07) now makes the condition
visible. That is a diagnosis, not a fix; the deferred fix on record is a third
monitor with `respectInhibitors: false` at ~30 minutes.

#### What counts as an inhibitor — measured 2026-09-07

The rule is about the surface's **role**, not about having a window. Measured in
a nested sway with no other clients, probing with
`swayidle -w timeout 3 <marker>`; the first and last rows are the controls that
give the test power, and they come out mirror images.

| Case | Inhibitor attached to | Idle notification |
| --- | --- | --- |
| A | nothing (control) | **fires** |
| B | visible `xdg_toplevel` | inhibited |
| C | quickshell layer surface (`PanelWindow` + `IdleInhibitor`) | **fires** — not inhibited |
| D | `xdg_toplevel` on a hidden workspace | **fires** — not inhibited |
| E | `wayland-pipewire-idle-inhibit`'s layer surface | inhibited |
| E′ | same process, inhibitor released | **fires** |

Re-run 2026-09-07 in a **headless** nested sway, which renders independently of
the host session and so removes the failure that invalidated the first re-run.
Row C was verified to the standard row B always had: the bar's `#0000aa` is
painted at the top of the captured output (so the layer surface is mapped),
`WAYLAND_DEBUG` shows
`zwp_idle_inhibit_manager_v1.create_inhibitor(..., wl_surface#35)` and no
matching `destroy`, and both controls behave. Row C reproduced. Setting an
explicit `screen`, anchoring all four edges and moving to the background layer
changed nothing.

**The mechanism is not established, and the obvious theories are all wrong.**
A reviewer reading sway's `sway_idle_inhibit_v1_is_active` reports that a mapped
layer surface should inhibit and a view-less surface should not — the opposite of
both C and E. "It is about the surface role" does not survive either, because E
turned out **not** to be a roleless surface: the trace shows
`zwlr_layer_shell_v1.get_layer_surface(...)`. So E and C are *both* layer
surfaces, and they behave differently. The one difference visible in the traces
is that w-p-i-i never attaches a buffer (its surface is never mapped) while
quickshell's is mapped and painted — which is backwards from the source. Treat
the rows as measurements, not as a rule, until someone reads the sway build's
actual source.

Two consequences that do **not** depend on the mechanism:

- **A daemon with no visible window can hold an effective inhibitor**, because
  `wayland-pipewire-idle-inhibit` demonstrably does (E, with E′ as the mirror
  control). Whatever the rule is, its recipe works: a `zwlr_layer_surface_v1`
  anchored to all four edges on an explicit output, with no buffer ever
  attached.
- **Quickshell's `IdleInhibitor` on a `PanelWindow` does not work** (C).
  CLAUDE.md's conclusion — that quickshell's own surfaces cannot inhibit idle —
  is confirmed, so `Bar.qml`'s `IdleInhibitor { window: bar }` is **dead code**
  and has never inhibited anything. The stated reason (layer-shell role) is not
  the mechanism, since E is a layer surface too.

This makes the "one protocol, two producers" option viable: `noidle` and
Insomnia's third mode can hold a *Wayland* inhibitor through a small helper with
no visible window, after which a single mechanism governs the dim, the lock and
any screen-off, all enforced compositor-side. `noidle` would keep its logind
inhibitor for the `sleep` half, which still matters on the laptop.
`IdleService`'s special-case read of `InsomniaService.mode.inhibitIdle` could
then go away, since the inhibitor would be honoured for real.

No such helper is packaged — `apt-cache search` turns up only
`wayland-pipewire-idle-inhibit` itself — so it is ~50 lines of new code, or a
reuse of that project's `idle_inhibitor/wayland` module.

### 4. swayidle is an unsupervised single point of failure — RISK

It is started by `exec_always` in `.config/sway/config` — not a unit, no
`Restart=`, nothing watching it. Three of the four ways this session locks run
through it:

| Trigger | Route | Via swayidle |
| --- | --- | --- |
| `$mod+Escape` | `loginctl lock-session` → logind `Lock` → swayidle → `lock` | yes |
| Power menu → Lock | identical to the keybind | yes |
| Idle at 300s | `IdleService` → `execDetached(["lock"])` | no |
| Before sleep | logind `PrepareForSleep` → swayidle → `lock` | yes |

If it dies, all three **fail silently**: the keybind appears to do nothing, and a
manual `systemctl suspend` would sleep an unlocked desktop. Only the 300s idle
lock survives.

All four converge on `.local/bin/lock`, which is idempotent, starts
`quickshell-lock.service` and waits up to 2s for the `secure` stamp before
returning — falling back to `swaylock -f` if it never arrives. That wait is what
keeps `before-sleep` inside logind's `InhibitDelayMaxUSec` (5s) budget without
suspending over a half-mapped surface.

### 5. The screen never powers off, for a reason belonging to another machine — RISK

Both the idle dim and the lock blank are *paints*, never a modeset. The reason on
record is `sway-lockup-investigation.md`, whose root cause is
`Failed to disable CRTC` on **Intel Iris Xe** with connectors `eDP-1` and
`HDMI-A-1` — that is the laptop.

This host is an **RTX 4080 SUPER** driving a single DisplayPort output. The policy
is shared through the dotfiles and has never been re-tested here, so the G9 is held
at full display power around the clock on the strength of a different GPU's bug.
Whether DPMS is safe here is **unknown** — worth an experiment, not a blind change.

### 6. logind's idle machinery is inert — NOTE

`IdleAction=ignore`, so the 30-minute `IdleActionUSec` fires nothing, and
swayidle's `idlehint 120` sets a hint with no consumer.

**Corrected 2026-09-07 after review.** An earlier version of this finding said a
logind idle inhibitor "changes no behaviour on this machine at all". That is
wrong. **swayidle itself honours them**: `strings /usr/bin/swayidle` carries
`BlockInhibited`, `Logind idle inhibitor found` and
`Not enabling timeouts: idle inhibitor found`, and upstream disables *all* its
timeouts while logind reports idle blocked, re-enabling them on the
`BlockInhibited` property change. So a logind idle inhibitor already suppresses
`idlehint 120` today, and would suppress the dim, the lock and the screen-off
the moment those move into swayidle.

It remains true that logind's own `IdleAction` is `ignore` and therefore fires
nothing, and that quickshell's `IdleMonitor`s do not see logind inhibitors. The
live value is `BlockInhibited = ""` on this host, so the effect is latent rather
than active.

Note also that logind refuses a *delay*-mode idle inhibitor outright ("Delay
inhibitors only supported for shutdown and sleep"), so every idle row in
`ListInhibitors` is a block.

**`ignore` is systemd's default, not Debian's.** `man 5 logind.conf` states it
("Defaults to "ignore""), `/etc/systemd/logind.conf` ships with every line
commented out, and there is no vendor file under `/usr/lib/systemd` overriding
it — so this is the default on any systemd distribution, which is why it keeps
turning up. The reason is in the same paragraph: the action runs only "after all
sessions report that they are idle", and logind cannot observe a graphical
session's idleness itself — it knows only what a session reports through
`SetIdleHint`. Here that reporting is swayidle's `idlehint 120` and nothing
else.

**Would `IdleAction=lock` help?** Partly, and not the part that matters.
Measured 2026-09-07 with `WAYLAND_DEBUG=1`: swayidle binds `ext_idle_notifier_v1`
at **version 1** and calls `get_idle_notification` for both its timeouts,
including the idlehint one. It never calls `get_input_idle_notification`, the
inhibitor-ignoring variant, which requires version 2 — although sway advertises
version 2. So **the idle hint is suppressed by Wayland idle inhibitors exactly
like everything else**: a leaked Chrome inhibitor stops the hint being set,
logind's countdown never starts, and `IdleAction=lock` cannot serve as the
ceiling finding 3 wants. It does not help with finding 4 either, since both the
hint and the action route through swayidle.

What it does buy is one real redundancy — if quickshell dies or is restarted
while the session is unattended, swayidle still sets the hint and logind still
emits `Lock` → swayidle → `lock`, which starts a *separate* unit — plus the side
effect of giving logind idle inhibitors their first consumer, so `noidle` and
Insomnia's third mode would begin inhibiting something real. `IdleActionSec`
should then stay far from IdleService's 300s so the two never race; the default
30min, counted from the hint at 120s, locks at ~32min and therefore only ever
fires when the shell is not doing its job.

### 7. logind is never told the session is locked — NOTE

Nothing calls `SetLockedHint` — not the lock client, not swayidle — so
`LockedHint` reads `no` whether or not the screen is locked. Harmless today, since
nothing consumes it; it would quietly mislead anything added later that asks
logind whether the session is locked.

## What unlocks the session

| Route | Detail |
| --- | --- |
| Password | `PamContext(config: "swaylock")` → `/etc/pam.d/swaylock` → `common-auth` → `pam_unix`. On success the lock drops and the process quits 250ms later. Nothing else is in the stack. |
| Signal | SIGTERM or SIGKILL to the lock client — finding 2. Also how `loginctl unlock-session` works, via swayidle's `unlock` hook. |

The keyring is not implicated either way: `pam_gnome_keyring` appears in
`common-password` and `cinnamon-screensaver` but in neither greetd's nor
swaylock's stack, and the Secret Service default collection reads
`Locked=false` regardless.

## What holds idle off

| Kind | Reaches the dim and lock? |
| --- | --- |
| Application (Wayland) | **Yes**, but only while the window is visible. |
| sway `inhibit_idle` | **Yes** — `$mod+Shift+i` marks a window `no idle`, with a visible border. |
| wayland-pipewire-idle-inhibit | **Yes** — takes a Wayland inhibitor whenever audio plays. |
| Insomnia, third mode | **Yes**, by a side door: `IdleService` reads `InsomniaService.mode.inhibitIdle` directly. Its own `IdleInhibitor` sits on the bar's layer surface, which sway ignores. |
| logind (`systemd-inhibit`, `noidle`) | **Not** quickshell's `IdleMonitor`s — but **yes** to swayidle, which disables every timeout while `BlockInhibited` names idle. See finding 6. |

## What could not be measured

**The 240s dim and 300s lock were not clocked.** Doing so needs the session
genuinely idle, and the Claude desktop app holds a Wayland idle inhibitor for the
whole length of every turn — so any idle probe run from an agent session is
inhibited by the act of running it. A number from that test could not distinguish
"the timeout is wrong" from "my own client blocked it", so the constants are
reported as constants. Measuring them needs a detached probe (`systemd-run --user`)
started and then left alone, or a hand test.

**Finding 1's refusal is derived, not executed**, for the reason given there.

## Environment gotchas for next time

- **`pgrep -f` and `pkill -f` match the agent's own shell.** The harness runs
  commands through a `zsh -c '…'` whose command line contains the pattern being
  searched for, so `pgrep -f "quickshell -p …/lock.qml"` returns the shell's pid
  and `pkill -f "sleep 600"` kills the shell running the command. Both happened
  here; the first produced a "kill: no such process" that briefly looked like the
  lock client had died on its own. Match on the binary (`pgrep -x`) and
  disambiguate with `/proc/<pid>/environ`.
- **`swaymsg workspace "<name>"` collapses runs of spaces**, so restoring a saved
  workspace name creates a *duplicate* workspace and leaves the original hidden
  with its windows on it. Return by focusing a window that was there
  (`swaymsg '[app_id="…"] focus'`) instead.
- **Capture a nested compositor through its own display, not the host output.**
  `WAYLAND_DISPLAY=<nested> grim out.png` asks the nested compositor for its own
  framebuffer and is unaffected by anything happening on the real session.
  Capturing the host output at the nested window's rect is not equivalent: once
  the real session locks, the lock surface covers the whole output and every
  such capture silently photographs the lock screen instead — a plausible dark
  frame rather than an error. That invalidated an entire re-run of finding 2,
  and led to a stretch of blaming the nested compositor for "broken rendering"
  that was never broken. Also check
  `systemctl --user is-active quickshell-lock.service` before and after any
  capture-based experiment, and prefer a discriminator that is not a pixel at
  all: an IPC query, a protocol trace, or a marker file.
- **A manual lock leaves no journal trace.** `loginctl lock-session` is a D-Bus
  call and swayidle's `lock` hook logs nothing, so the absence of a trace does
  not mean the idle timer fired. Do not infer the cause of a lock from the
  journal.
- **Search the journal for the natural experiment before building a rig.** The
  question "does a dying lock client unlock the session?" was answered on this
  host, on real hardware, on 2026-09-05 — a lock client died and was replaced a
  second later. A nested sway was built to ask what the journal had already
  recorded, and the nested rig then produced two invalid results before it
  produced a valid one.
- **The protocol XML is on disk**, under
  `~/.local/share/cargo/registry/src/*/wayland-protocols-*/protocols/`. No
  network needed to check what a compositor is required to do.
- **Do not use red as an "unlocked" marker in a lock experiment** — sway paints
  an abandoned lock red.
- Testing a session lock needs a nested sway, and a demo overlay is
  indistinguishable from a real lock by eye — check `WAYLAND_DEBUG` for
  `ext_session_lock_manager_v1` before trusting any lock measurement.

## The design, as built (2026-09-08)

DPMS was independently re-tested on the laptop and is **not** a problem there,
so finding 5 is closed and a real `output power off` is back on the table.

**swayidle owns idle policy; the shell only draws.** This is the opposite of
what the 2026-09-07 review recommended, and it is a deliberate call: swayidle is
the standard sway tool for this, it already had to exist for logind's
Lock/Unlock/PrepareForSleep, and one mechanism that is slightly worse beats two
that are each slightly better. The review's objections are answered below rather
than dismissed.

`.config/systemd/user/swayidle.service`:

```
idlehint 120
timeout 240  quickshell ipc call idle dim   resume  quickshell ipc call idle undim
timeout 300  loginctl lock-session
timeout 600  swaymsg output '*' power off   resume  swaymsg output '*' power on
lock         systemctl --user start quickshell-lock.service
unlock       systemctl --user stop quickshell-lock.service
before-sleep ~/.local/bin/lock
```

### What the review objected to, and what became of it

- **"A logind idle inhibitor silently suppresses everything."** True, and now
  intended: swayidle disables *all* its timeouts while one is held, so `noidle`
  and Insomnia's third mode inhibit the dim, the lock and the screen-off for
  real, through the ordinary path. The objection was that the second channel was
  unmonitored; the bar's coffee cup, added 2026-09-07, is what answers it.
  `IdleService`'s side-door read of `InsomniaService.mode.inhibitIdle` is gone,
  and so is `Bar.qml`'s `IdleInhibitor`, which had never inhibited anything.
- **"Redundancy goes down."** Accepted. swayidle is now the single point of
  failure for all four lock paths, which is why supervising it moved from an
  improvement to a prerequisite and was done first. Its unit carries
  `Restart=always` and, deliberately, **no start limit** — the same reasoning as
  `quickshell-lock.service`: a unit that gives up leaves a session that never
  locks, silently.
- **"The ceiling and the design are in conflict."** Resolved by dropping the
  ceiling. `respectInhibitors: false` is available only to quickshell, and
  swayidle binds `ext_idle_notifier_v1` at version 1 so it structurally cannot
  ignore an inhibitor. There is therefore no upper bound on a leaked inhibitor,
  **by choice**: a 30-minute ceiling would lock during any film, since
  `wayland-pipewire-idle-inhibit` holds an inhibitor whenever audio plays. The
  coffee cup is the answer instead. Action item 5 is **withdrawn**.
- **"The dim has no failure signal."** Still true — `quickshell ipc call idle
  dim` exits 0 and prints `Target not found.` when the shell is down. The
  consequence is now bounded: a dead shell costs the dim and nothing else,
  because the lock does not go through the shell at all.
- **"before-sleep must stay `lock`."** Kept, and it is the one place the line
  departs from a plain `systemctl --user start`. `-w` blocks until the command
  returns; `.local/bin/lock` does not return until the compositor confirms the
  surfaces are mapped, while `systemctl start` on a `Type=simple` unit returns
  as soon as the process forks — which would release logind's sleep inhibitor
  over a half-mapped surface and resume to an unlocked desktop. `lock` also
  keeps the `swaylock -f` fallback.
- **"Two blanking mechanisms overlap."** Retired: `LockService.blankSeconds`,
  `blanked`, and the black `Rectangle` and `IdleMonitor` in `LockSurface.qml`
  are all deleted. `timeout 600` is the only screen-off.
- **"The laptop half is asserted, not designed."** Lid policy is deliberately
  unchanged: `HandleLidSwitch=suspend`, `HandleLidSwitchDocked=ignore`,
  `HandleLidSwitchExternalPower=ignore`, so a lid closed on mains blanks the
  panel and is caught by the ordinary 300s lock rather than locking at once.

### Measured while building this (2026-09-08)

- **`QS_DISABLE_FILE_WATCHER=1` disables quickshell's config watcher.** A/B on a
  scratch config, editing the loaded file: the control logged `Reloading
  configuration` once, the guarded run zero times. That is the whole fix for
  finding 2b — one `Environment=` line in `quickshell-lock.service` — and it is
  cheaper than the config-root split the finding proposed. There is no CLI flag;
  the variable is the only lever.
- **systemd's quoting carries the commands through intact.** Probed with a
  script that dumps its own argv from a real unit: `timeout 240 "quickshell ipc
  call idle dim"` arrives as one argument and `%h` expands inside the quotes.
  The single quotes in `"swaymsg output '*' power off"` are load-bearing —
  systemd keeps inner quotes literally and swayidle runs the string through
  `/bin/sh`, where a bare `*` globs against the working directory. Confirmed:
  unquoted, `output * power off` expanded to the contents of `$HOME`.
  `systemctl show` cannot check this, since it joins argv with spaces.
- **The dim paints and unpaints exactly.** `grim` luma over the whole screen:
  27.25 → **10.74** → 27.25 across dim/undim, i.e. 0.394 of baseline against the
  shade's 0.6 opacity. Both IPC edges work and undim restores the frame exactly.
- **The unlock IPC works.** A demo-mode lock process registers target `lock`
  with `unlock()`, and calling it makes the process exit cleanly — which is what
  `ExecStop=` relies on, so `systemctl --user stop` now sends
  `unlock_and_destroy` instead of the SIGTERM that abandons the lock. Finding 2
  is fixed. The trade, stated plainly: any same-uid process can now unlock
  without the password, which is the authority logind already assumes for
  `loginctl unlock-session`.
- **`output <name> power on|off` is the current spelling** (`dpms` is a
  deprecated alias) and `get_outputs` reports `power` per output, which is what
  the unit's `ExecStartPre` guard reads: a swayidle restarted while the outputs
  are off would otherwise start un-idle, never fire the resume, and strand a
  black screen. The guard issues nothing when every output is already on,
  because a `swaymsg output` is a full modeset.
- **swayidle 1.9.0 gates only its timeouts on logind inhibitors**
  (`Disable idle timeouts`, `Not enabling timeouts: idle inhibitor found`). The
  `lock`/`unlock`/`before-sleep` hooks are D-Bus signal handlers and are
  unaffected, so an inhibitor cannot suppress a lock that was asked for.

### Why the chain needed a manual test

Everything above is measured, but **the chain itself cannot be exercised from an
agent session** — the 240s dim, the 300s lock, the 600s power-off and its
resume, `before-sleep` on a real suspend, and `loginctl unlock-session` against
a real lock all need the session genuinely idle, and the Claude desktop app
holds a Wayland idle inhibitor for the length of every turn. A number from that
test could not distinguish "the timeout is wrong" from "my own client blocked
it". So it was handed over rather than guessed at.

### The manual test came back green (2026-09-08)

Every case passed: the fast checks, the full 10-minute idle run, the inhibitor
cases (`noidle` and Insomnia's third mode now really do hold the dim and the
lock off, which they never did before), sleep and lid, and the recovery cases —
including editing QML while locked, which used to kill the lock client.

**Finding 1 is fixed as a result.** `PowerService.qml` now asks logind at
startup, with one `busctl` loop over `CanSuspend`, `CanHibernate` and
`CanSuspendThenHibernate` — they are methods rather than properties, so
`busctl get-property` cannot read them. Suspend dispatches
`suspend-then-hibernate` where it is offered and plain `suspend` where it is
not; Hibernate is dropped from the list rather than shown and refused. Probed
rather than hardcoded because the two machines need not agree and the answer
moves with Secure Boot. Verified three ways: as measured (Suspend alone, plain
`systemctl suspend`), with hibernation forced available
(`suspend-then-hibernate` plus a Hibernate row), and with nothing available
(both gone).

**Finding 7 is fixed too.** `LockService` calls `SetLockedHint` — true on
`secure`, false when `locked` drops — so `LockedHint` follows reality whichever
path locked the session. `session/auto` resolves to the user's display session
even from a user unit with no session and no `XDG_SESSION_ID`, measured against
a login shell, and the write needs no polkit. Exercised by driving the two
transitions: `false` → `true` on secure → `false` on unlock, with the
mirror control that an unlock *without* a preceding lock leaves an externally
set hint alone, which is what keeps demo mode from reporting an unlock that
never happened.

**Hibernation will not be restored on this desktop** — decided 2026-09-08, so
the Secure Boot question is closed rather than deferred. The runtime probe is
still the right shape, because the laptop may answer differently.

### Still open

1. **A swayidle restart resets its timers**, and its `delay` sleep inhibitor is
   not held across the restart window. Inherent to the design; recorded so it is
   not rediscovered as a bug.

## Superseded: the 2026-09-07 proposal, kept for its reasoning

Goal: **one lock path and one inhibitor mechanism**, working unchanged on the
desktop (which stays up for weeks and never sleeps) and the laptop (which
suspends, resumes and has a lid).

Three principles:

1. **swayidle owns idle policy; quickshell only draws.** swayidle is the only
   thing here that can hear logind's `Lock`/`Unlock`/`PrepareForSleep` —
   quickshell 0.3.0 has no logind client — so it is already load-bearing.
   Moving the timeouts into it takes quickshell out of the decision to lock,
   which is the security-relevant half. Reimplementing it in quickshell is not
   worth it: the subtle part is `-w`'s blocking `before-sleep`, and the rest is
   a few hundred lines that already exist and are packaged.
2. **Every lock request funnels through `loginctl lock-session`** → logind
   `Lock` → swayidle's `lock 'lock'` hook. `$mod+Escape` and the power menu
   already do this; the idle timeout would join them. One path, and it keeps
   working if quickshell is restarted.
3. ~~**Inhibition is Wayland-only**, enforced compositor-side.~~ **Falsified
   2026-09-07** — see finding 6. swayidle disables *every* timeout while a logind
   idle inhibitor is held, so moving the timeouts into it makes any
   `systemd-inhibit --what=idle` from anything silently suppress the dim, the
   lock and the screen-off, on a second unmonitored channel with nothing logged.
   That is finding 3's unbounded-inhibitor risk made strictly worse. Latent
   today (`BlockInhibited = ""`), but it is a property of the design, not of the
   current state.

```
swayidle -w \
    idlehint 120 \
    timeout 240 'quickshell ipc call idle dim'  resume 'quickshell ipc call idle undim' \
    timeout 300 'loginctl lock-session' \
    timeout 600 'idle-screen-off'               resume 'idle-screen-on' \
    lock 'lock' \
    unlock 'systemctl --user stop quickshell-lock.service' \
    before-sleep 'lock'
```

Four things about that line that are easy to get wrong:

- **`before-sleep` must stay `lock`, not `loginctl lock-session`.** `-w` blocks
  until the command finishes, and `lock` blocks until the compositor confirms
  the surfaces are mapped. `loginctl lock-session` returns as soon as the D-Bus
  call is dispatched and the locking then happens asynchronously through the
  same swayidle — so the sleep inhibitor would be released with the lock surface
  possibly not up, and the laptop could suspend over an unlocked desktop and
  resume to it. This is the one place the single-funnel rule costs the guarantee
  the funnel exists for.
- **`resume` binds to the preceding `timeout`**, per `man swayidle`
  (`timeout <timeout> <cmd> [resume <cmd>]`). The dim needs its own or returning
  at 250s leaves the screen dimmed.
- **`timeout 600 'output * power off'` is lockup trigger #2**, and the laptop is
  the machine that bug lives on. It goes behind a per-host script
  (`idle-screen-off`), on the same pattern as `sway-outputs`' overrides, and
  lands only after the DPMS re-test in action item 4. There is no per-host
  mechanism in `.config/sway/config` today beyond the two generated includes.
- **`IdleService` has no `IpcHandler`**, so the dim needs one added.

### What this supersedes

`IdleAction=lock` **drops out entirely.** Its action is to emit logind's `Lock`
signal, and the only thing that acts on `Lock` here is swayidle's own hook — so
it can only help while swayidle is alive, and if swayidle is alive its own
`timeout 300` has already fired. It covered a dead quickshell, which this design
removes from the lock path anyway. Action item 6 is withdrawn.

### Open objections from review (2026-09-07)

The design has **not** survived review intact. Beyond principle 3 above:

- **Step 2 (the windowless helper) is viable** — row E re-ran clean — but it must
  copy `wayland-pipewire-idle-inhibit`'s recipe (an unmapped layer surface
  anchored to all edges on an explicit output), **not** quickshell's
  `IdleInhibitor`, which is measured not to work. Since the mechanism behind that
  difference is unexplained, the helper needs its own regression check.
- **Redundancy goes down, not up.** Today two independent things can lock the
  session — quickshell's 300s monitor and swayidle's logind hooks. The design
  collapses both into swayidle and offers `Restart=always` as the mitigation, but
  supervision covers *exit*, not a swayidle wedged in a `-w` command, nor the
  restart window during which its `delay` sleep inhibitor is not held
  (`DelayInhibited = "sleep"` confirms it is held today), nor timers resetting on
  restart. The objection raised against `IdleAction=lock` — "it only helps while
  swayidle is alive" — then applies to the whole lock chain.
- **Principle 1's premise is overstated.** Quickshell has no logind *binding*,
  but this codebase already runs `nmcli monitor`, `swaymsg -t subscribe` and
  `camera-watch` as long-lived `Process`es for exactly this, and
  `InsomniaService` already holds a logind inhibitor through `systemd-inhibit`.
  It is a preference, not a capability limit. The security framing is weak too:
  quickshell is already the polkit agent and runs as the same uid as swayidle.
- **A one-line alternative gets principle 2 with none of the cost:** leave the
  timeouts in `IdleService` and change its lock call to
  `execDetached(["loginctl", "lock-session"])`. Same single funnel, both lock
  paths stay independent, the action-item-5 ceiling stays implementable
  (`respectInhibitors: false` is available *only* to quickshell — swayidle binds
  `ext_idle_notifier_v1` at version 1 and structurally cannot ignore
  inhibitors), and it needs no IPC handler, no helper and no swayidle unit.
- **The ceiling and the design are in direct conflict** and the design does not
  say so: principle 1 removes the only component that can implement it.
- **The laptop half is asserted, not designed.** No lid handling
  (`HandleLidSwitchDocked = ignore`, so a docked lid-close neither suspends nor
  locks and `sway-laptop-lid` just blanks the panel); no `after-resume` hook;
  and `sway-laptop-lid:55` already issues `swaymsg output <panel> disable` — a
  full modeset — on the very Intel host whose CRTC bug is cited to gate
  `idle-screen-off`, so either the modeset fear is overstated or that script is
  a live instance of it.
- **Two blanking mechanisms overlap** — `LockService.blankSeconds` at lock+60s
  and `timeout 600 'idle-screen-off'` — and the design retires neither.
- **The dim has no failure signal**: `quickshell ipc call idle dim` exits 0 and
  prints `Target not found.` when the shell is down.

### Work in dependency order

1. **Supervise swayidle** (`swayidle.service`, `PartOf=graphical-session.target`,
   `Restart=always`), replacing the `exec_always killall swayidle` line. This
   moves from an improvement to a **prerequisite**: today swayidle's death costs
   three of four lock paths, and under this design it costs all of them plus the
   dim and the screen-off.
2. **A windowless Wayland idle-inhibit helper**, so `noidle` and Insomnia's third
   mode inhibit the same way everything else does. `noidle` keeps its logind
   inhibitor for the `sleep` half, which still matters on the laptop.
   `IdleService`'s side-door read of `InsomniaService.mode.inhibitIdle` and
   `Bar.qml`'s dead `IdleInhibitor` both go.
3. **Add the `idle` IPC handler to `IdleService`** and move the timeouts into
   swayidle.
4. **DPMS re-test**, then `idle-screen-off` if it passes.
5. **The lock-kill decision** (finding 2) — policy, settle before code.

Stages 1 and 2 are independent of each other; 3 depends on both; 4 and 5 are
independent of all of it.

## Action items — all settled

Kept as a ledger; the reasoning is in "The design, as built" near the top.

0. **Stop the lock client watching the shell's config tree** (finding 2b) —
   **done**, `QS_DISABLE_FILE_WATCHER=1` in `quickshell-lock.service`. A/B'd.
1. **Fix the two dead power-menu actions** (finding 1) — **done**, but not as
   proposed: rather than hardcoding this host's answer, `PowerService` probes
   logind's `CanSuspend`/`CanHibernate`/`CanSuspendThenHibernate` at startup, so
   the laptop can differ and the answer follows Secure Boot. Restoring
   hibernation on this desktop (disabling Secure Boot, or signing for it) was
   considered and declined — it is not wanted here.
2. **Fix `loginctl unlock-session`** (finding 2) — **done, and not the way this
   item proposed.** Quickshell exposes no signal handling, so there is no way to
   trap SIGTERM in `lock.qml`. Instead the unit's `ExecStop` calls a new `lock
   unlock` IPC handler, which drops `LockService.locked` so the client sends
   `unlock_and_destroy` and exits before any signal is sent. The finding's claim
   about SIGKILL was right and has not been touched.
3. **Put swayidle under supervision** — **done**, `swayidle.service`,
   `Restart=always`, no start limit. It went from an improvement to a
   prerequisite when swayidle took over every timeout.
4. **Re-test DPMS** — **done**, on the laptop, which is the machine whose Intel
   CRTC failure the no-modeset policy came from. Clear, so `timeout 600` powers
   the outputs off for real and the lock surface's black paint is gone.
5. **A ceiling on inhibitor-suspended idle** — **withdrawn.** A 30-minute
   ceiling would lock during any film, and swayidle cannot ignore inhibitors
   anyway. The bar's coffee cup is the answer instead.
6. **Set `IdleAction=lock` as a backstop** — **withdrawn** on 2026-09-07, before
   any of this: it can only act while swayidle is alive, and while swayidle is
   alive its own timeout has already locked.
