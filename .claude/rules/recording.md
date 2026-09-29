---
paths:
  - ".local/bin/record-region"
  - ".config/quickshell/services/RecordingService.qml"
  - ".config/quickshell/modules/bar/Recording.qml"
---

# Screen recording

`$mod+Ctrl+p` toggles a wf-recorder capture into
`$(xdg-user-dir VIDEOS)/Recordings`. How each rule here was established is in
`.claude/recording-reference.md`; read the relevant part there before changing a
mechanism described here.

- The selection is `grimshot anything`'s: visible window rects to slurp on stdin
  plus `-o`. It stays a shell script because its jq filter is full of
  backslashes, which a QML string would eat.
- `RecordingService.framerate` pins 60fps; by default wf-recorder follows the
  output's refresh (240Hz on the G9).
- The recorder is a quickshell `Process`, deliberately: wf-recorder finalises
  its container on SIGTERM, so a shell restart **stops** a recording cleanly.
  The `exec` in its `sh -c` is load-bearing, or the shell eats the signal and
  the file is never finalised. Check with `ps -o ppid=` on the wf-recorder pid.
- Colour: wf-recorder writes limited-range BT.601 YUV and tags it full range.
  Keep
  `-p color_range=tv -p colorspace=bt709 -p color_primaries=bt709 -p color_trc=bt709`
  **and** `-F "scale=out_color_matrix=bt709"`. `-x yuv420p` does not help. mpv
  honours the tags and is the honest viewer; VLC guesses.
- Test a colour matrix on the **Y plane** against a `grim` capture, on colourful
  and motionless content, never with a whole-frame average.
- wf-recorder does not exit on a region it cannot capture. The service reads
  stderr with a `SplitParser` (not a `StdioCollector`), then stops, deletes the
  file and notifies.
- The bar item hangs off the clock's left edge and its binding warms the
  singleton. Park the pointer before comparing `grim` captures of the bar.
