---
paths:
  - "system/greetd/**"
  - "system/install-greetd"
---

# Login (greetd + gtkgreet)

How each rule here was established is in `.claude/login-reference.md`; read
the relevant part there before changing a mechanism described here.

- greetd on VT7 runs a bare sway hosting gtkgreet; choosing a session runs
  `uwsm start -- sway.desktop`. Neither machine autologins.
- These files are root-owned in `/etc`, so they are **copied, not linked**:
  `sudo ./system/install-greetd` after any edit. That script is the whole
  procedure (group hedge, validation, enable).
- Validate a sway config with `WLR_BACKENDS=headless` and a throwaway
  `XDG_RUNTIME_DIR`. Plain `sway --validate` under sudo fails on good and bad
  configs alike. A typo'd input identifier is not a parse error.
- gtkgreet reads `/etc/greetd/environments` (raw command lines), not
  `wayland-sessions`. The second line, `zsh -lc sway`, is a rescue that skips
  uwsm.
- **Keep `source_profile = false`**: uwsm sources the profile itself, and
  `~/.profile` prepends to `PATH` without a guard. The greeter then has no
  `PATH`, so anything it runs that searches `PATH` itself (e.g. `strace`) needs
  an absolute path.
- The greeter's sway config must not include `/etc/sway/config.d/*`. Its
  `output` line is keyed by identifier to match `sway-outputs`, so login does
  not add a modeset.
- **Keep `DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent`** on greetd's
  `command`. With a session bus, gtkgreet blocks inside `gtk_init` on a portal
  that can never start (25s per attempt, 0.07s without). Client-side flags
  (`GTK_USE_PORTAL=0`, `NO_AT_BRIDGE=1`, `GIO_USE_VFS=local`,
  `XDG_CURRENT_DESKTOP`) were measured and do not help.
- greetd's journal carries no sway or gtkgreet output: redirect `command`'s
  output to a file to see it. Reproduce outside the login path with a real
  `user@105.service` and `setpriv` inside a headless nested sway. A
  hand-started `dbus-daemon` is not equivalent.
- `_greetd` reaches the GPU by logind ACL and cannot read `~`: the wallpaper
  is copied to `/etc/greetd/`, and `GTK_THEME=Adwaita:dark`.
- `gtkgreet.css` is hand-written Catppuccin Mocha and not in `theme`'s targets
  (`theme` never needs root). Widget ids: `#body`, `#clock`, `#input-field`,
  `#command-selector`.
- Recovery: `Ctrl+Alt+F2`. greetd gives up after 5 restarts in 30s. Test a
  change by switching to a getty **first** and restarting greetd from there.
