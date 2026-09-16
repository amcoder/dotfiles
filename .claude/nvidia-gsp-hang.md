# demise: sway hangs in the NVIDIA driver on DPMS resume (2026-09-14)

Status: **mechanism measured, driver held at 610.57.04, which has held through
several lock → blank → wake cycles since (2026-09-14/15).** This is the desktop
(RTX 4080 SUPER, open kernel module, G9 on DP-2 at 5120x1440@240) and is
unrelated to `sway-lockup-investigation.md`, which is the laptop's i915 bug.

## Symptoms

Screen black after the monitor has been powered off by the idle timeout and
something wakes it. Keyboard and mouse do nothing, the bar flickers, a VT
still works. `sudo reboot` from the VT is the only way out: `quickshell-lock`
survives two SIGKILLs at shutdown, and the reboot itself takes over a minute.

## Mechanism

sway is not blocked — it is `state:R`, **spinning inside an nvidia modeset
ioctl**, holding the driver's modeset semaphore:

```
drm_mode_atomic_ioctl → nv_drm_atomic_commit → nvKmsIoctl → nvSetDispModeEvo
  → KickoffProposedModeSetHwState → nvUpdateInfoFrames → nvEvo1SendDpInfoFrameSdp
  → rpcRmApiControl_GSP → _issueRpcAndWait → kgspRecvPoll        ← never returns
```

The modeset issues RPCs to the GPU's GSP firmware and **the GSP has stopped
answering anything**. Three snapshots over seven minutes show the same poll
loop under different callers: 13:20 (hung-task dump, `?`-frames, unreliable)
under `nvUpdateInfoFrames → nvEvo1SendDpInfoFrameSdp`; 13:24 (NMI backtrace,
reliable) under `nvEnableVrr → ConfigVrrPstateSwitch`, the poll loop itself in
`kgspHealthCheck → crashcatEngineGetNextCrashReport` — the driver reading the
GSP's crash-report queue; and at 13:27 sway is off-CPU and not in D, while
`nvidia-modeset/` (kthread 1439) holds the semaphore instead, polling on a
DisplayPort AUX transaction RPC. So each RPC spins to its multi-minute timeout
and the next one hangs the same way, every one holding the modeset lock.
Everything that touches NVKMS queues behind it: chrome, slack and
gnome-system-monitor were all D in `nvkms_close` on exit, and the kernel logs
`blocked on a semaphore likely last held by task sway:2610`, preceded by
`nvidia-modeset: WARNING: GPU:0: Lost display notification` and
`ERROR: GPU:0: SLI raster lock timeout exceeded`. With sway's main thread in
the kernel nothing is rendered or dispatched, and a process inside an ioctl
cannot be killed — hence the unkillable lock client.

The `nvEnableVrr` frame is not a lever: sway has adaptive sync **disabled** on
DP-2 (`adaptive_sync_status: disabled`), and NVKMS runs that path on every
modeset regardless.

Raw captures, taken over ssh while hung: `~/nvidia-hang-2026-09-14-1324.log`
and `~/nvidia-hang-final-2026-09-14-1327.log` (sysrq `w` + `l` via `dmesg`).
`~/sway-bt-2026-09-14-1325.log` is empty — gdb cannot stop a task that is in
the kernel, so `thread apply all bt` hung and had to be killed; `strace -p`
and `perf top -p` fail the same way. The kernel side is the only side with
anything to say here.

### Recognising it live, from ssh, without root

```
ps -eo pid,stat,wchan:40,comm | grep -E 'sway|nvidia|quickshell'
```

```
   1439 D    -                                        nvidia-modeset/kthread_q
   2610 Rsl  -                                        sway
   2675 Ss   do_epoll_wait                            swayidle
 126416 S    unix_wait_for_peer                       swaymsg
```

`nvidia-modeset/kthread_q` in **D** with `sway` in **R** and no wchan is the
signature: sway is spinning inside the ioctl, not sleeping. The `swaymsg` in
`unix_wait_for_peer` is swayidle's `output '*' power on`, which sway will never
read. Everything else — quickshell, swaybg, Xwayland — is idle in `poll` and is
a bystander. `sudo cat /proc/<sway pid>/stack` shows the `kgspRecvPoll` frames
directly if root is to hand; `echo w > /proc/sysrq-trigger` dumps the D-state
kthread with the semaphore owner named.

## Trigger

The DPMS **power-on**, not the power-off and not the lock. Both crashed boots
are the same shape:

```
boot -2   02:33 lock → 02:43 output power off (ok) → 10:18:26 power on → +0.6s sway has no output
boot -1   13:02 lock → 13:07 output power off (ok) → 13:09:26 power on → +0.6s sway has no output
```

`no output to auto-assign layer surface 'quickshell' to` from sway is the
moment it lost the output. The 10:18 wake was the MX Master reconnecting over
Bluetooth. Not every resume hangs: the same boot survived an off/on 20s apart,
and boot -4 ran 97 quick lock cycles that never idled long enough to reach the
600s power-off. A lock is simply how the monitor gets powered off.

## Why now

`apt upgrade` on 2026-09-13 23:08 took the driver **610.57.04 → 615.71.09**
(released 2026-09-09), with new GSP firmware. The previous boot ran 8 days on
610.57.04 (Sep 5 → 13) with 24 locks and the same swayidle config, and ended
with a deliberate shutdown; the three short boots that evening were BIOS
visits to enable XMP, not lockups. Every DPMS-resume hang is on 615.

## What was done

- `system/apt/nvidia-driver` pins every driver package at 610.57.04-1 with
  priority 1001, installed by `sudo ./system/install-apt`. `Package:` mixes a
  `/nvidia/:any` regex with the five packages whose names lack the string
  (`libcuda1`, `libcudadebugger1`, `libnvcuvid1`, `libnvoptix1`,
  `libxnvctrl0`); Debian's own `firmware-nvidia-graphics` has no such version
  and is unaffected. **A bare name or regex matches the native architecture
  only** -- without `:any` the eleven i386 packages stayed at candidate 615
  and every `apt upgrade` listed them as "kept back", held only by their
  multi-arch dependency on the pinned amd64 halves. Dry-run an edit with
  `apt-cache -o Dir::Etc::PreferencesParts=<dir> -o Dir::Etc::Preferences=/dev/null policy`
  over all 59 packages, and check first that the harness is reading the temp
  file and not `/etc` -- in zsh an unquoted `$opts` string is one word, and
  apt then silently reads the installed pin, which is how a working file was
  misdiagnosed as broken.
- `nvidia-driver-check` on a daily user timer notifies through the bar when
  the repo carries a version newer than any seen before, and when the pin has
  stopped holding (candidate ≠ installed — e.g. 610 removed from the repo).
  The first run records the newest and stays silent, so arming it does not
  announce 615. The bar's own apt indicator cannot do this: it parses `Inst`
  lines, and a pinned package produces none.

## Verifying a new driver

The test with power is the one that failed: lock, let it idle to the 600s
power-off, wait a few minutes, wake it. Twenty seconds off is not enough —
that case survived on 615. Do it a few times; the hang is not deterministic.

## Environment notes

- Kernel messages are root-only here (`dmesg_restrict`, not in `adm`).
  `journalctl -k` implies `-b`, so use `sudo journalctl _TRANSPORT=kernel`
  for every boot.
- `journalctl --list-boots -o json` timestamps are UTC; the text form is local.
- Upstream release list: github.com/NVIDIA/open-gpu-kernel-modules/releases.
  nvidia.com's release-notes pages are rendered client-side and fetch empty.
