# Idle, dim, lock and unlock — audit (2026-09-07)

Host: **demise** (RTX 4080 SUPER, single DP-2 output, Odyssey G9). sway 1.12
(packaged), quickshell 0.3.0, session started by uwsm.

Status: **read-only audit, nothing changed.** Seven findings; two are broken
outright. Action items at the bottom.

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

### 2. Killing the lock client unlocks the session — BROKEN

SIGTERM *or* SIGKILL to the process holding the session lock drops the lock: the
desktop is exposed within 400ms, with no `unlock_and_destroy` request ever sent.
Anything running as this uid can do it with one signal, and
`systemctl --user stop quickshell-lock.service` is exactly that signal.

**This contradicts CLAUDE.md**, which records that a SIGKILL while locked leaves
the session locked and that a replacement client re-confirms `secure`. The more
likely reading of that earlier observation is that `Restart=on-failure` put a
*new* client up quickly enough to look like the lock had never dropped.

Consequences:

- `Restart=on-failure` is not the safety net it reads as. A crash exposes the
  desktop for `RestartSec=1` plus quickshell's startup; a clean stop exposes it
  permanently, since a clean exit deliberately does not restart.
- The same behaviour is what makes swayidle's `unlock` hook work at all —
  `loginctl unlock-session` → `systemctl --user stop quickshell-lock.service`
  really does unlock.

How it was established, in a nested sway so the real session was never at risk:

- Nested sway with `output * bg #ff0000 solid_color`, so locked and unlocked are
  separable by colour: red `(255,0,1)` against the lock screen's crust
  `(21,20,31)`, measured as the mean pixel of a `grim` capture.
- The real `lock.qml` run against it. `WAYLAND_DEBUG=1` confirms it binds
  `ext_session_lock_manager_v1`, calls `.lock()`, and receives
  `ext_session_lock_v1#37.locked()` — so this is a genuine session lock and not
  the `QS_LOCK_DEMO` overlay, which would have produced identical pixels and
  made the whole test powerless.
- SIGTERM and SIGKILL each tested twice. Red returns within 400ms and is still
  red 62s later.
- **The control that actually settles it**, because pixels alone could not: a
  *second* lock client was granted a fresh `locked()`. A compositor still
  holding a lock must answer `finished()` instead. Sway's own state machine
  therefore says unlocked.

One observation from those runs is unexplained and deliberately not chased: the
nested sway reported a *visible* Alacritty in `get_tree` that it was not
painting, while the output showed only the background. It does not bear on the
conclusion, which is protocol-level rather than pixel-level.

### 3. One Wayland inhibitor suspends the whole chain, with no ceiling — RISK

Both `IdleMonitor`s set `respectInhibitors: true`, so while any application idle
inhibitor sits on a **visible** window there is no dim and no lock — indefinitely,
silently, nothing logged. Chrome PWAs leak these and the Claude desktop app holds
one for the length of every turn.

The lock surface's own 60s blanking uses the same monitor, so locking by hand
while an inhibitor is held leaves **the lock screen lit at full brightness** for
as long as it is held. That half is derived from the shared mechanism rather than
separately measured.

The bar's coffee-cup indicator (added 2026-09-07) now makes the condition
visible. That is a diagnosis, not a fix; the deferred fix on record is a third
monitor with `respectInhibitors: false` at ~30 minutes.

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

The consequence for the new idle-inhibit indicator: a **logind idle inhibitor
changes no behaviour on this machine at all** — not the lock, and not logind's own
idle action, because there isn't one. They are still worth listing, being real
inhibitors and the mechanism Insomnia's third mode uses, but no entry in that
section of the panel can ever explain a screen that will not lock.

Note also that logind refuses a *delay*-mode idle inhibitor outright ("Delay
inhibitors only supported for shutdown and sleep"), so every idle row in
`ListInhibitors` is a block.

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
| logind (`systemd-inhibit`, `noidle`) | **No** — and per finding 6, now reaches nothing at all. |

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
- Testing a session lock needs a nested sway, and a demo overlay is
  indistinguishable from a real lock by eye — check `WAYLAND_DEBUG` for
  `ext_session_lock_manager_v1` before trusting any lock measurement.

## Action items

1. **Fix the two dead power-menu actions.** `PowerService.qml`'s Suspend should
   dispatch `systemctl suspend` on a host where `CanSuspendThenHibernate` is `na`,
   and Hibernate should not be offered at all. Deciding whether to *restore*
   hibernation (disabling Secure Boot, or signing for it) is a separate question.
2. **Decide what a killed lock client should mean.** The options are to accept it
   (the lock defends against a passer-by, not against your own uid) or to make the
   unit restart on a clean stop too and reach `loginctl unlock-session` some other
   way. Either way, correct the CLAUDE.md claim that a SIGKILL leaves the session
   locked.
3. **Put swayidle under supervision**, or move its three logind hooks into
   something that is. Its silent death currently disables the lock keybind and
   before-sleep locking with no symptom.
4. **Re-test DPMS on this host.** The no-modeset policy was inherited from the
   laptop's Intel CRTC failure and has never been exercised on NVIDIA. If it
   holds, `output power off` at the lock blank saves the panel being lit all night.
5. **Consider a ceiling on inhibitor-suspended idle** — the deferred third
   `IdleMonitor` with `respectInhibitors: false`. Findings 3 and 6 together mean
   there is currently no upper bound on how long a leaked inhibitor keeps the
   session unlocked.
