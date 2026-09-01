# Sway session lockup — investigation notes (2026-09-01)

Status: **root cause identified, nothing fixed yet.** Four action items at the bottom.

## Symptoms

Screen goes black. Only Chrome and the quickshell bar remain visible, and the bar
closes and reopens repeatedly. Networking appears to be down. Keyboard input does
not reach applications. The only way out is switching to a Linux VT and rebooting.
Seemed to correlate with changing themes.

## Root cause

sway's DRM backend cannot disable the CRTCs, so it cannot re-enable them either,
and is left with no usable output.

In every crashed boot the last thing sway logs is the same pair, with the reboot
following moments later:

```
boot -3  01:23:56  connector eDP-1: Failed to disable CRTC 309
                   connector HDMI-A-1: Failed to disable CRTC 171     → reboot 01:25:58
boot -2  01:30:37  (same two lines)                                   → reboot 01:31:09
boot -1  01:41:36  (same two lines)                                   → reboot 01:41:50
```

Boot -3 has the full arc, and it maps onto the symptoms one-for-one:

```
01:20:55  connector eDP-1:    Failed to disable CRTC 309
01:20:55  connector HDMI-A-1: Failed to disable CRTC 171
01:20:55  no output to auto-assign layer surface 'quickshell' to   ← the bar
01:23:34  Atomic commit failed: Invalid argument
01:23:34  Backend commit failed                                    ← a sway reload
01:23:51  Failed to disable CRTC (both connectors)
01:23:54  Atomic commit failed: Invalid argument / Backend commit failed
01:23:56  Failed to disable CRTC (both connectors)
```

`no output to auto-assign layer surface 'quickshell' to` is the bar having nowhere
to map — that is the "closes and reopens over and over". Nothing crashes, which is
why the journal is otherwise silent for the whole black-screen window and why sway,
quickshell and dunst all keep running and logging. A VT still works because it is a
separate path.

## Why it is the apt upgrade, not the theme work

The `apt upgrade` on 2026-08-31 23:47 replaced the whole graphics stack at once:
kernel 7.1.3 → **7.1.12**, mesa 26.1.5, wlroots 0.20.x, wayland 1.25.0,
xwayland 24.1.12, libqt6waylandclient6, and firmware-linux / firmware-intel-graphics
/ firmware-iwlwifi 20260622-1.

Timeline:

```
boot -5   Aug 4 09:12 → Sep 1 00:05    28 days uptime, clean reboot
          ^ ALL the quickshell + theme + theme-picker work happened here (Aug 31, 10:00–23:44)
Aug 31 23:47  apt upgrade
boot -4   00:06 → 00:39   (33 min)  ← reboot from tty1
boot -3   00:41 → 01:25   (44 min)  ← reboot from tty1
boot -2   01:26 → 01:31   (5 min)   ← reboot from tty1
boot -1   01:31 → 01:41   (10 min)  ← reboot from tty1
```

The entire theme system, the picker, and repeated theme switching all happened
during a boot that stayed up 28 days.

The discriminating counter — **check this one, not `Atomic commit failed`**:

```
                          atomic-commit-failed   CRTC-disable-failed
boot -5 (28 days, old kernel)      4924                  0
boot -4                              21                  0
boot -3                              10                  6
boot -2                               2                  2
boot -1                               0                  2
```

`Atomic commit failed` is longstanding background noise on HDMI-A-1 (all
`Device or resource busy` page-flips) — 4924 across 28 stable days. It is **not**
the signal and will mislead. `Failed to disable CRTC` is: zero in 28 days on the
old kernel, present in three of the four crashed boots.

### Why it looked like the theme code

`theme set` ends in `swaymsg reload`, which makes sway re-commit its output
configuration — a full modeset, which is the path that now fails (the
`Backend commit failed` lines at 01:23:34 and 01:23:54 are reloads). The theme code
is not at fault; it just exercises the broken kernel path more often than anything
else. The other trigger is swayidle's `timeout 600 'swaymsg "output * power off"'`,
which disables both CRTCs directly.

## Ruled out (do not re-investigate)

- **Kernel/GPU/firmware log evidence** — `journalctl -k` is clean through the
  failure window: no i915 hang, no GPU reset, no iwlwifi error. This is expected;
  an atomic commit rejected with `-EINVAL` is a return code to userspace, not a
  kernel warning. The evidence is in *sway's* log, not the kernel's.
- **Resource exhaustion** — `TasksMax=infinity` on the user slice; session bus
  limits are 100000 (`max_connections_per_user`, `max_completed_connections`).
- **Process crash loop** — sway and quickshell were both alive and quiet for the
  entire black-screen window. quickshell relaunched 19 times across 44 min in
  boot -3, matching manual theme switches, with none after 01:18:53 (7 min before
  the reboot).
- **Output hotplug churn** — swaybg logged one output event per sway reload and no
  more; outputs were not appearing/disappearing.
- **quickshell I3 workspace-model desync** — the
  `quickshell.I3.ipc: Workspace "..." doesn't exist` warnings do track theme changes
  exactly (each embedded hex is the *outgoing* theme's accent, because
  `rename_workspaces` in `.local/bin/theme` renames every workspace), but boot -5
  had 204 of them across 28 days without incident. Normal churn.

## Environment gotchas for next time

- **The journal hides system messages.** The user is not in `adm` or
  `systemd-journal`, so plain `journalctl` silently shows only user-session
  messages, and `dmesg` is blocked (`kernel.dmesg_restrict=1`). Root-level reads
  need `sudo journalctl ...` run by the user. `sudo usermod -aG adm amcoder`
  (then re-login) would fix this permanently.
- Sway's own errors *are* visible in the user journal, tagged with the main sway
  pid. Find it with:
  ```
  journalctl -q -b -N --no-pager | grep -m1 'sway/config.c' | sed -E 's/.*sway\[([0-9]+)\].*/\1/'
  ```
- **sway is a custom build**: `1.12-rc3-affdd1a2 (May 14 2026, branch 'custom')`,
  while the packaged version is `sway 1.12-1`. It links against `libwlroots-0.20`,
  which that upgrade moved to 0.20.2. Worth rebuilding against the current wlroots
  regardless of how the kernel question resolves.
- Kernels still installed to fall back to:
  `linux-image-7.1.3+deb14-amd64` (the 28-day-stable one) and
  `linux-image-7.0.12+deb14.1-amd64`. Select from GRUB → Advanced options.
- GPU is Intel TigerLake-LP GT2 (Iris Xe, `8086:9a49`). Outputs in play are
  `eDP-1` (laptop, usually disabled) and `HDMI-A-1` (Samsung Odyssey G93SC).

## Action items

1. **Confirm the kernel.** Boot `7.1.3` from GRUB → Advanced options and run on it.
   If stable, the kernel is implicated. If it still locks up, the firmware/mesa side
   is (those are not kernel-version-dependent), and the next step is downgrading
   `firmware-intel-graphics` / `mesa-libgallium` from `/var/cache/apt/archives`.

2. **Mitigate on 7.1.12.** Drop the `timeout 600 'swaymsg "output * power off"'`
   idle action from `.config/sway/config:42` — it is the one thing that deliberately
   disables both CRTCs on a timer.

3. **Fix the dunst D-Bus activation loop** (a real bug in this repo, but *not* the
   crash — log noise and wasted processes only). After every theme switch,
   `dunstctl` starts D-Bus-activating `dunst.service` on every call instead of
   routing to the already-running daemon: 255 activations in boot -3, driven by the
   5-second poll at `.config/quickshell/Dunst.qml:22`
   (`sh -c "dunstctl is-paused; dunstctl count waiting"`, two `dbus-send` calls
   each). Zero occurrences in boot -5 before any theme switch; dormant again after a
   fresh login. Something about `theme apply`'s `dunstctl reload` +
   `swaymsg reload` puts it into this state — reproduce by switching themes and
   watching:
   ```
   journalctl -q -b 0 --no-pager | grep -c 'Started dunst.service'
   ```

4. **Fix `.config/sway/config:39`** — it runs `~/bin/sway-laptop-lid`, but the
   script is at `~/.local/bin/sway-laptop-lid` and `~/bin` does not exist. The lid
   handler has never run; every sway start/reload logs
   `sh: 1: /home/amcoder/bin/sway-laptop-lid: not found`.

### Not a bug (checked, leave alone)

`exec_always killall quickshell; quickshell` (line 81) and the swayidle line (42)
both log `[ERROR] [sway/config.c:637] Unknown/invalid command '...'` on every start.
sway splits the line on `;` and tries to parse the tail as a sway command, which
fails — but the shell still receives the whole string, so both commands do run.
Verified with `ps`: `sh -c killall quickshell; quickshell` with a live quickshell
child. Cosmetic log noise only.
