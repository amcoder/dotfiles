# Screencasting reference

The full notes behind `rules/screencast.md`: how each fact there was
established, what was measured, and what was tried first. Moved verbatim from
CLAUDE.md.

**Screencasting** (`.config/xdg-desktop-portal-wlr/config`,
`.local/bin/screencast-chooser`, `services/ScreencastService.qml`,
`modules/screencast/`): sway 1.12 and wlroots 0.20 can share a **single window**
rather than a whole output, and xdg-desktop-portal-wlr 0.8.4 speaks the
`ext_foreign_toplevel_list_v1` and `ext_image_copy_capture_v1` needed for it.
What was missing was the picker: with no `chooser_cmd` configured xdpw walks a
built-in list of dmenu-alikes and lands on **wmenu**, a one-line list of raw
labels with the toplevel's identifier hanging off the end of each.
`screencast-chooser` replaces it with a Quickshell grid of live thumbnails.

**The chooser is a protocol, not a program.** `chooser_type=dmenu` means xdpw
forks `chooser_cmd` through `/bin/sh -c` with a pipe on each end, writes one
label per line to its stdin, closes it, then **`waitpid`s for the process to
exit before reading a single line back** from its stdout. So a chooser cannot
stream an answer and stay alive: it blocks until the user picks, prints one
line, exits. The reply must be a label xdpw itself produced — it regenerates
each one and `strcmp`s it — so labels are echoed back byte for byte and never
rebuilt. Printing nothing is a cancel, and the whole exchange happens during
**`SelectSources`**, not `Start`.

The labels are `Monitor: <name> <description>` and
`Window: <title> (<identifier>)`. Parse a window label **from the right**:
titles routinely contain " (" themselves, as in
`Messages - (1) Google Messages for web`. That identifier is the hinge the whole
feature turns on — it is `ext_foreign_toplevel_list_v1`'s, and it is the same
string in three places: sway's IPC tree exposes it per container as
`foreign_toplevel_identifier`, and `grim -T <identifier>` captures by it.
Matching on title would have been ambiguous between two windows of the same
name; matching on the identifier cannot be.

**Quickshell 0.3.0 cannot capture a toplevel, so the thumbnails are grim's.**
`ScreencopyView` looks like the obvious answer and is not: its three backends
are `IccOutputSourceManager` (ext-image-copy-capture), `WlrScreencopyManager`
and `HyprlandScreencopyManager`, and only the Hyprland one takes a window.
Handed a wlr `Toplevel` on sway it logs
`Capture source set to non captureable object` and draws nothing — measured
across all 13 open windows, every one `hasContent: false`, `sourceSize: -1x-1`.
The binary does carry the string
`ext_foreign_toplevel_image_capture_source_manager_v1`, which makes it look
supported; no class binds it.

grim does bind it. `grim -T <identifier>` captures a window **that is not
visible** — occluded, or on another workspace — which is exactly the case that
matters, since a region grab of the window's rect would return whatever is
painted on top of it. Measured on 13 windows: 12 succeeded including seven on
other workspaces, and one Electron window (Claude) failed with `Invalid stride`,
so a failed capture is expected rather than exceptional and the picker falls
back to the app icon. All of them in parallel cost ~320-500ms at `-s 0.25 -l 1`.
Scale is computed per window from sway's rect against a 640px target rather than
fixed. Debian's grim is built **without jpeg** (`jpeg support disabled`), so PNG
is not a preference.

**`grim -T` hangs on a toplevel xdpw is already capturing** — which is precisely
the window that matters, the one just shared. Measured on one window:
162/161/160ms with nothing streaming, then, while xdpw held a capture session on
it, one 161ms run followed by two still running at 6s, with a different window
captured at the same instant in 6ms. It does not hang on _every_ attempt, and
that intermittency is what makes a per-capture timeout the wrong shape: the
first re-share looks fine and the next two do not. With a per-capture timeout of
8s the picker appeared **8.4s** after the share button on every re-share (8419ms
and 8471ms, against 469ms for the first share of a session). Thumbnails are
therefore bounded by a budget for the _whole batch_ (`CAPTURE_BUDGET`), and
whatever has not arrived by then falls back to the app icon.

**xdpw services nothing while the chooser runs**, and this is the thing to keep
in mind before putting any work in it. Its event loop is single-threaded and
sits in `waitpid`: asked for a D-Bus property it replies in 0ms before and after
the picker, and not at all — two 5s timeouts — while the picker is open. So
every second the chooser spends is a second an _already running_ screencast is
frozen, which is why the hung capture above was worse than a slow picker and why
re-sharing while presenting was the case that broke. Anything slow belongs
outside the chooser, or bounded.

**A shared window that is not repainting delivers no frames, so the app sits
forever on "Starting presentation".** This is the one to know, because every
symptom it produces points somewhere else. xdpw's toplevel capture only hands
PipeWire a frame when the client commits a new buffer, and a static window
commits none — so the consumer waits for a first frame that never arrives.
Anything that makes the window repaint starts it instantly: focusing it, moving
the mouse over it, or the window animating on its own. A window containing an
animated GIF **never** hangs, which is the control case that proves it.

It is not the chooser and not the thumbnails. Measured by disabling thumbnail
capture entirely, so the chooser opened no capture session on any toplevel: the
hangs continued unchanged. Everything the chooser does is finished and correct
before the failure begins — it answers, exits, and only then does xdpw's capture
fail to produce.

This also explains why `grim -T` hangs on a toplevel xdpw is streaming, recorded
above as a capture-session conflict. The likelier reading is the same damage
rule: a single-shot capture gets the compositor to composite the toplevel on
demand, while a second, concurrent session waits for damage that a static window
never produces. The batch budget is the right fix either way, but do not trust
the "already capturing" explanation for it.

Two dead ends worth not repeating. **Making the window _visible_ is not enough**
— switching to its workspace left the stream just as dead, because visibility is
not repainting. And **`pw-top` cannot tell a working share from a hung one**:
both show `QUANT=0 RATE=0 W/Q ???` on the video nodes, since those columns are
meaningless for nodes that are not clock-driven. The link shows `active` and the
format negotiated in both cases too. The only reliable signal is whether the
picture appears.

**A wedged screencast is cleared by restarting the portal, not the browser** —
`systemctl --user restart xdg-desktop-portal-wlr`. Once, every share hung at
Firefox's "Starting presentation", consistently and across a Firefox restart,
and came back on the next xdpw restart with no code change. The chooser was not
implicated: it ran and produced a valid label, which its replay state file
records on every pick. The mechanism was never established, so this is a
recovery procedure and not an explanation.

Two things that look like they would diagnose it and do not, both learned the
hard way. **A portal handshake test proves nothing**: a client that drives
`CreateSession`/`SelectSources`/`Start` and stops there never consumes the
stream, so it reports success whether or not frames are flowing — which is
exactly the failure being investigated. And **xdpw logs nothing at all while a
share is live**, even at `-l TRACE`; measured across a known-good share and a
hung one, both zero lines between the session-start and session-close bursts, so
the journal cannot separate them either. What does show it is `pw-top`, or
`pw-dump` filtered to xdpw's node, which report whether the node is actually
producing; both ship with pipewire and are installed.

Two things about `quickshell ipc call`, both of which cost a debugging session:

- **It interprets an argument that looks like JSON** instead of passing it
  through. An array sent inline came back with its outer brackets stripped and
  parsed as a bare object, whose `length` is `undefined` — so the picker opened
  with every target filtered away and showed "No matches". The targets go over a
  **file** now, and only paths cross the IPC boundary. Anything structured wants
  the same treatment.
- **It exits 0 when the call did not land**, printing `Target not found.` or
  `Function not found.` on _stdout_. The exit code is only meaningful for a
  shell that is not running at all, which is 255 with `No running instances`.
  The chooser therefore tests both, and on either falls back to xdpw's own
  chooser list — a broken bar must not take screensharing down with it.

The answer comes back over a **FIFO** in the chooser's own temp directory,
because `quickshell ipc call` returns as soon as the QML function does and
cannot wait on a user. The chooser opens the read end _before_ asking the shell,
so the writer can never arrive first; `O_NONBLOCK` is what allows that open with
no writer yet, and a writer that opens and closes without writing arrives as a
readable end-of-file, which is the cancel. Every path that fails to show the
picker must still answer that FIFO — a `FileView` that will not load included —
or the chooser blocks, and xdpw's `waitpid` blocks behind it, wedging every
later screenshare until the portal is restarted. `PICK_TIMEOUT` is the backstop
for a shell that dies mid-pick.

The thumbnails are pictures of the user's windows, so the temp directory is
removed on the way out and a `SIGTERM` handler turns a kill into a `SystemExit`
so that cleanup actually runs.

**Chrome asks more than once for a single share, so the chooser replays its
answer.** Measured at TRACE over one Google Meet share: **three**
`CreateSession`/`SelectSources` rounds in nine seconds, every one of them
`types: 2`. The first ran to completion and returned PipeWire node 123, which
Chrome then closed; the second was abandoned without ever calling `Start`; only
the third became the stream. Nothing in the portal path failed — the chooser
answered all three correctly with the same label — so this is Chrome's own flow,
and wmenu did it too. Teams is Chrome as well, so it behaves identically.

With the replay in place, four consecutive Meet shares were **exactly three
rounds each**, every one of them one real pick followed by two replays: the pick
took 1.3-7.3s of the user deliberating, and the two replays 22-43ms with no
picker drawn. The gap from an answer to the next round is ~1.5s and then ~5ms,
consistently. The third round of every share offers one _more_ label than the
first two (14 against 13) — that is Chrome's own sharing-indicator window
appearing — which is exactly why the replay guard checks that the remembered
label is still on offer rather than that the list is unchanged.

**A cancel is the case that most needs this.** Declining a share produced
**six** further rounds at roughly half-second intervals, all of which the replay
answered as cancels. Without remembering the cancel, saying no once would mean
saying no seven times.

`screencast-chooser` therefore records its last answer in
`$XDG_RUNTIME_DIR/screencast-chooser.last` and replays it to a repeat request
inside `REPLAY_WINDOW` (5s), refreshing the timestamp each time so a _chain_ of
rounds keeps replaying rather than only the one after the pick. Across every
round measured the gap from one answer to the next request was at most 2.0s,
which is the evidence the window is generous enough while staying well below the
time it takes a person to stop a share and deliberately start another — a
genuine second share, twelve seconds after the previous answer, correctly fell
outside it and drew the picker. The guard is that the remembered label must
still appear in what xdpw just offered: the source list changes between rounds
(13, 13, then 14 labels, as Chrome's own sharing-indicator window appears), and
replaying a label xdpw did not just produce would come back as
`selected unknown target` and drop the session. A cancel is remembered too, so
declining a share declines the rounds behind it instead of asking once per
round. The replay is answered _before_ the thumbnails are grabbed, so a repeat
costs ~55ms and never flashes a picker.

This is the one part of the arrangement that is a workaround rather than a
mechanism, so it is worth knowing what it would look like if it misfired: a
share started within five seconds of the previous pick would silently reuse that
pick. Nothing observed comes close to that, but raising `REPLAY_WINDOW` is what
would make it reachable.

The picker itself is a grid rather than the shell's usual `FilterList`, since
what is being chosen is a picture; it reuses `Fuzzy` directly for the search
field but not `FilterList`, which is a `ListView` at heart. It is instantiated
once in `shell.qml` rather than per bar, like `PolkitDialog` — and that
instantiation is load-bearing for the usual reason: `ScreencastService` is
reached only over IPC, so without a `visible: ScreencastService.active` binding
to warm it the singleton would never be created and its `IpcHandler` never
registered.

Testing this without a meeting client means driving the portal over D-Bus
directly: `CreateSession` → `SelectSources` (`types: 3` for monitors and
windows) → `Start`, watching the `Response` signal on each `Request` path. A
window selection comes back as `source_type: 2` with a PipeWire node id. Raising
xdpw's log level needs a systemd drop-in
(`ExecStart=/usr/libexec/xdg-desktop-portal-wlr -l TRACE`), since it is D-Bus
activated and takes no arguments otherwise.
