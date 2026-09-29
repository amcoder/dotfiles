---
paths:
  - ".local/bin/sway-outputs"
  - ".local/bin/sway-scale"
  - ".local/bin/sway-toggle-aspect"
  - ".local/bin/sway-laptop-lid"
  - ".config/systemd/user/sway-outputs.service"
  - ".config/quickshell/services/DisplayService.qml"
  - ".config/quickshell/modules/display/**"
  - ".config/quickshell/modules/bar/Display.qml"
---

# Output configuration and the display panel

How each rule here was established is in `.claude/outputs-reference.md`; read
the relevant part there before changing a mechanism described here.

## sway-outputs

- The sway config names no output. Mode and scale are derived from each
  panel's EDID at login and on hotplug.
- Modes are ranked by **aspect ratio first** (against the physical size in the
  EDID), then pixel count, then refresh. Pixel count alone picks the G9's
  3840x2160 over its native 5120x1440.
- Scale is integer: 2 at or above 165 DPI, otherwise 1. `scaleOverrides` and
  `modeOverrides` at the top of the script key by sway identifier (preferred;
  connector names are not stable) or connector.
- With no readable EDID, do not guess: leave the output to sway and keep it
  out of the seen-set so it is retried.
- Physical size comes from `/sys/class/drm/card*-<name>/edid`. The connector
  dirs are symlinks (glob `(-/)`, not `(/)`), and sysfs attributes stat as zero
  bytes (test `-r`, never `-s`). Both fail silently.
- `(#b)` backreferences need `setopt extended_glob`. `die()` inside
  `resolve()` only exits its subshell, so overrides are validated up front.
- **Never issue a `swaymsg output` that is not a real change**: every one is a
  modeset, lockup trigger #1 (`.claude/sway-lockup-investigation.md`).
- What it resolves is also written to the generated
  `~/.config/sway/outputs.conf` (merged by identifier, never tracked), because
  sway resets an unconfigured output to its preferred mode and default scale
  on every apply, `swaymsg reload` included. A runtime override therefore
  lasts until the next reload.
- `watch` configures an output once, when it appears, and forgets it on
  disconnect, so a hand-set mode or scale is not undone by its own event.
- Subcommands: `show`, `scale`, `mode` (optionally with `W:H`, bounded to fit
  inside the native mode), `json` (every output in one call, for the panel).

## Lid and aspect toggle

- `sway-laptop-lid` finds the panel as any connected internal connector
  (`eDP`, `LVDS`, `DSI`), which is also the "is this a laptop" test. Lid state
  comes from logind's `LidClosed`, with the globbed ACPI path as fallback;
  with neither it does nothing. `lid:on` means shut. `--reload` on both
  bindings is load-bearing.
- `sway-toggle-aspect` compares resolution only and falls back to native from
  any third state.

## Display panel

- Everything it sets is a sway `output` directive over `I3.dispatch`, lasting
  until the next reload. "Native", "default" and the 16:9 candidate come from
  `sway-outputs json`, never a second copy of the ladder.
- Every setter compares against current state first: a same-value `swaymsg
  output … scale 1` still commits.
- Adaptive sync and HDR switches show only where `features` reports them and
  bind to reported state, not to the click.
- The last active output cannot be disabled.
- `native` is reserved in QML, hence `nativeMode`.
