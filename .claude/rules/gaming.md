---
paths:
  - ".config/gamemode.ini"
  - ".config/MangoHud/**"
  - ".config/mpv/**"
  - ".local/bin/hdr-run"
---

# Gaming

gamemode, MangoHud, ntsync, HDR and adaptive sync on demise. How each rule here
was established, with the benchmark figures, is in
`.claude/gaming-reference.md`; read the relevant part there before changing a
setting described here.

## Deliberately not done

A custom kernel (would mean rebuilding the NVIDIA module, held at 610), an
x86-64-v3 userland, zram, THP `always` and ananicy. Debian's kernel already has
what matters.

## gamemode

- Launch option: `gamemoderun mangohud %command%`. While a client is registered
  it sets `performance` governor/EPP, `split_lock_mitigate=0` and renices the
  game to -4, restoring all of it on exit. The governor is nearly all of its
  value.
- **`pin_cores=no`**: pinning to P-cores cost Cyberpunk 10% on the 1% lows and
  gained Factorio 6%. For a serial game, `taskset -c 0-15` in its launch option
  is the per-game override.
- `inhibit_screensaver=0` (nothing sane provides `org.freedesktop.ScreenSaver`
  here), `igpu_power_threshold=-1` (no iGPU). The daemon re-reads the file every
  5s, but a running client keeps its settings.
- Machine-local state, not tracked: membership of the `gamemode` group (created
  by `systemd-sysusers`), `limits.d/10-gamemode.conf`, and the ntsync module
  load.
- The renice limit reaches `gamemoded` from `user@1000.service`, which linger
  keeps alive across logout, so a re-login changes nothing: reboot, or
  `sudo prlimit --pid <user@ pid> --nice=30:30` and restart `gamemoded`.
- gamemode will not renice a process not at nice 0, and the Bash tool runs at
  non-zero nice: renice and ioprio can only be verified from a real terminal or
  Steam.

## Benchmarking

- Check `journalctl --user -u gamemoded` for `Entering Game Mode` before
  trusting a baseline: a game running under `gamemoderun` puts the whole machine
  in `performance`.
- Interleave configurations (A B C A B C) rather than running blocks.
- Cyberpunk: `Left Shift+F2` at the start of the benchmark flythrough with
  `log_duration=60`. `~/.local/state/MangoHud/summarise.py` reads the CSVs.

## MangoHud

- Debian's build has NVML stripped, so it is rebuilt locally as
  `0.8.4+dfsg-1+nvml1` and held
  (`mangohud mangohud:i386 mangohudctl mangoplot`), debs in
  `~/.local/share/mangohud-nvml/`. The recipe, including the i386 build in a
  container, is in the reference. Upstream's `include/nvml.h` from the matching
  tag, never the CUDA 13 header.
- `MANGOHUD_CONFIG` replaces the config file; test with `MANGOHUD_CONFIGFILE`
  pointing at a copy.
- `no_display` is set: `Right Shift+F12` shows it, `Left Shift+F2` logs 60s to
  `~/.local/state/MangoHud/` either way.
- `cpu_power` errors are noise (RAPL is root-only). The `GAMEMODE` line is not
  the daemon's state; `gamemoded -s` is.

## ntsync

Proton uses it automatically whenever `/dev/ntsync` exists (checked in
`wineserver`, so grepping `ntdll.so` or the `proton` script finds nothing).
MangoHud's `winesync` line confirms it. A/B with `PROTON_NO_NTSYNC=1`.

## HDR

- Needs `WLR_RENDERER=vulkan` (in `.config/uwsm/env`, gated to demise). The test
  for which renderer is running is `swaymsg output DP-2 hdr on`: GLES2 refuses
  it.
- HDR stays **off** at the desktop: with it on, every capture (grim,
  wf-recorder, screen sharing) comes out lifted and grey.
- `hdr-run` turns HDR on, runs `"$@"`, and turns it off on any exit. It must
  stay a script receiving arguments, never an `sh -c` wrapper (Steam's quoting
  breaks it). Launch option:
  `hdr-run env PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_HDR=1 gamemoderun mangohud %command%`.
- Proton Experimental cannot do HDR (X11 only); Proton-GE can.
- Films: `hdr-run mpv film.mkv`. `mpv.conf` only adds `hwdec=auto-safe`.
- The G9's EDID declares ~400 nits; set a game's peak by eye.

## Adaptive sync and input

- `output * adaptive_sync on` in the sway config. Check with `drm_info`
  (`vrr_capable`, `VRR_ENABLED`), not `swaymsg`. The failure mode is flicker in
  dark static content; the fix is `adaptive_sync off` per game.
- **Never add `seat * hide_cursor when-typing enable`**: in sway 1.12 it breaks
  every locked-pointer game (a key press clears pointer focus while a button is
  held).
