---
paths:
  - ".config/autostart/**"
  - ".config/systemd/user/poweralertd.service.d/**"
---

# Autostart

How each rule here was established is in `.claude/autostart-reference.md`; read
the relevant part there before changing a mechanism described here.

- Apps start through **XDG autostart**, run by uwsm's
  `wayland-session-xdg-autostart@sway.desktop.target`, not a sway `exec`.
  Anything the compositor does not itself need goes here, so systemd owns its
  lifecycle.
- An autostart entry that has "always been fine" may never have run: the old
  `sway-run` launcher did not process autostart.
- Three mechanisms, in order of preference:
  1. A system entry that already exists needs nothing (`nm-applet`).
  2. A new tracked entry in `.config/autostart/` for what ships none
     (`kdeconnect-indicator.desktop`, `calibre.desktop`).
  3. A `Hidden=true` shadow of the same name suppresses a system entry
     (`blueman.desktop`; blueman-applet is still the BlueZ agent, so it is
     shadowed rather than removed).
- A duplicate start is silent: the second instance exits successfully and the
  unit sits `inactive`.
- Ordering does not matter for tray apps.
- `poweralertd` runs with `-s` (ignore startup events) because it exits when its
  first notification fails. **Do not reach for unit ordering**:
  `After=quickshell.service` deadlocks at parse time, a retry budget does not
  work because `RestartSec` is ignored during session startup, and `gdbus wait`
  in `ExecStartPre` deadlocks the whole session. Read a daemon's own options
  first, and verify a startup race across a real reboot.
- `kde-baloo.service` is masked (machine-local).
- `1password.desktop` is written by 1Password itself and not tracked. The
  `polkit-kde-authentication-agent-1.desktop` link is inert (`OnlyShowIn=KDE;`).
