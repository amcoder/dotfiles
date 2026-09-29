---
paths:
  - ".local/bin/screencast-chooser"
  - ".config/xdg-desktop-portal-wlr/**"
  - ".config/quickshell/services/ScreencastService.qml"
  - ".config/quickshell/modules/screencast/**"
---

# Screencasting

Window sharing through xdg-desktop-portal-wlr, with `screencast-chooser` as its
picker. How each rule here was established is in
`.claude/screencast-reference.md`; read the relevant part there before changing
a mechanism described here.

## The chooser protocol

- xdpw forks `chooser_cmd` via `/bin/sh -c`, writes one label per line, closes
  stdin, then **waits for the process to exit** before reading one line back.
  Block, print one line, exit. Printing nothing cancels. This all happens during
  `SelectSources`.
- Echo a label back byte for byte: xdpw `strcmp`s it.
- Labels are `Monitor: <name> <description>` and
  `Window: <title> (<identifier>)`. Parse window labels **from the right**;
  titles contain " (". The identifier is the same in the label, sway's
  `foreign_toplevel_identifier` and `grim -T`.
- **xdpw services nothing while the chooser runs**, including a screencast that
  is already live. Anything slow belongs outside the chooser, or bounded.

## Thumbnails

- Quickshell cannot capture a toplevel on sway (`ScreencopyView` only takes
  windows on Hyprland), so thumbnails are `grim -T <identifier>`, which works on
  occluded and off-workspace windows. PNG only: Debian's grim has no jpeg.
- Some captures fail (`Invalid stride`); fall back to the app icon.
- `grim -T` can hang on a window being streamed. Thumbnails are bounded by
  `CAPTURE_BUDGET` for the **whole batch**, never a per-capture timeout.

## Talking to the shell

- Targets go to the picker over a **file**, never as an IPC argument
  (`quickshell ipc call` mangles JSON-looking arguments).
- `ipc call` exits 0 when it did not land; test for `Target not found.` and
  `Function not found.` too, and on any failure fall back to xdpw's own chooser
  list.
- The answer returns over a FIFO opened `O_NONBLOCK` **before** asking the
  shell. Every path that fails to show the picker must still answer the FIFO, or
  xdpw wedges. `PICK_TIMEOUT` is the backstop.
- The temp directory (pictures of the user's windows) is removed on exit; a
  `SIGTERM` handler makes that happen on kill too.
- `ScreencastService` is IPC-only, so the `visible: ScreencastService.active`
  binding in `shell.qml` is what creates it.

## Replay

- Chrome (and Teams) asks two or more times per share; a cancel produces several
  more rounds. The chooser records its last answer in
  `$XDG_RUNTIME_DIR/screencast-chooser.last` and replays it inside
  `REPLAY_WINDOW` (5s), refreshing the timestamp on each replay, and only if
  that label is still on offer. Cancels are replayed too. Replays happen before
  any thumbnails are grabbed.
- Raising `REPLAY_WINDOW` risks a new share silently reusing the old pick.

## Frozen shares and diagnosis

- **A static shared window delivers no frames**, so the app sits on "Starting
  presentation" until the window repaints. It is not the chooser, and making the
  window visible is not enough.
- A wedged portal is cleared by
  `systemctl --user restart xdg-desktop-portal-wlr`, not by restarting the
  browser.
- A handshake-only portal test proves nothing (it never consumes the stream),
  and xdpw logs nothing while a share is live. `pw-top` cannot tell a working
  share from a hung one. Whether the picture appears is the signal.
- To test without a meeting client, drive the portal over D-Bus: `CreateSession`
  → `SelectSources` (`types: 3`) → `Start`. TRACE logging needs a systemd
  drop-in on xdpw's `ExecStart`.
