---
paths:
  - ".local/bin/sysmon-watch"
  - ".config/quickshell/services/SystemMonitorService.qml"
  - ".config/quickshell/modules/bar/SystemMonitor.qml"
  - ".config/quickshell/modules/sysmon/**"
  - ".config/quickshell/widgets/GaugeIcon.qml"
  - ".config/quickshell/widgets/HistoryGraph.qml"
---

# System monitor

**System monitor** (`.local/bin/sysmon-watch`,
`services/SystemMonitorService.qml`, `modules/bar/SystemMonitor.qml`,
`modules/sysmon/SystemMonitorPanel.qml`, `widgets/{GaugeIcon,HistoryGraph}`): a
CPU and a memory gauge in the right section between Insomnia and the display
item, one clickable unit opening a `BarPopup` with a minute of CPU, memory and
network history, every core, swap, load, uptime and the top processes, with
`gnome-system-monitor` as "advanced…". `GaugeIcon` is the glyph as its own
gauge: drawn in `surface2`, with a copy in the level colour (`barStatusline`,
yellow from 70%, red from 90%) clipped from the bottom up. The fill spans the
glyph's _ink_ and not the square, so each icon carries `glyphTop`/`glyphBottom`
read off the Phosphor path (cpu 16-240 of 256, memory 56-208); without that a
10% reading fills nothing visible and 90% looks full.

`sysmon-watch` is a persistent Python process emitting one JSON line a second,
read with a `SplitParser` and restarted by the same 10s timer `camera-watch`
has. The per-process scan is the only part that costs anything, so it runs only
while `detail on` has arrived on stdin (`Process.stdinEnabled` + `write()`),
which the panel sends on `expanded` and re-sends from `onStarted` so a restarted
watcher comes back in the right mode. Measured on the 28-core desktop: 1-2ms/s
with the panel closed, ~19ms/s with it open. History is uniform because the
interval never changes; only the scan is gated. The first scan after `detail on`
takes a baseline and emits no list, since an all-zero CPU column would sort by
pid; kernel threads (RSS 0) are dropped; a process's `cpu` is its share of _all_
cores so the column sums consistently with the total. Network counts only
interfaces with a `/sys/class/net/<name>/device`, which leaves out `lo` and
bridges. The panel's process list is fixed at eight rows so the list arriving
two seconds after the card opens does not grow it, and sorting by CPU or memory
is client-side over a union of the watcher's top twelve by each.
