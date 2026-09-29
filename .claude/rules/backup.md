---
paths:
  - ".local/bin/backup"
  - ".local/bin/backup-*"
  - ".config/backup_exclude"
  - ".config/systemd/user/backup*"
  - ".config/quickshell/backups.qml"
  - ".config/quickshell/services/BackupService.qml"
  - ".config/quickshell/modules/bar/Backup.qml"
  - ".config/quickshell/modules/backup/**"
---

# Backup

An rsync-over-ssh `--link-dest` snapshot of `$HOME` to
`backup@beedle:/volume1/backup/impa/amcoder`, run by systemd timers, with a bar
indicator and a browser. How each rule here was established is in
`.claude/backup-reference.md`; read the relevant part there before changing a
mechanism described here.

## Ground truth

- **Mail on this machine is broken** (sendmail not running, a deferred
  queue), so the mailbox is not a record of anything. Whether a backup ran is
  answered on the NAS: `latest` and the `daily.N` mtimes.
- The eighteen-month outage was the DSM auto-block and `Too many
  authentication failures` feeding each other, both from `Host *
  IdentityAgent`. `IdentitiesOnly` cut it (see `rules/nas-mounts.md`).

## Units

- `OnFailure=backup-failed@%n.service`, and the handler uses `%i`, never
  `%I`.
- `ExecCondition` probes `beedle:22` with `nc -z` (exit 1 skips). `ssh true`
  would exit 255, which counts as failure.
- `LogRateLimitIntervalSec=0`, because `rsync -v` is a line per file.
  `--partial` stays, `-P` is gone.
- `Persistent=true` catches up after downtime, so enabling a timer with
  `--now` starts a run: not while one is already going.
- `ExecStartPre=backup-record start` / `ExecStopPost=backup-record finish`
  keep `$XDG_STATE_HOME/backup/status.json`. `ExecStopPost` runs on every
  outcome and decides the run's fate from `$SERVICE_RESULT`.
- A stop exits 143 (listed in `SuccessExitStatus`), recorded as `stopped`;
  the TERM trap removes the half-built temp directory. A manual run rotates
  `daily.N` like any other.

## The script

- Any non-zero rsync exit discards the whole run. Code **24** (vanished
  files) is tolerated; **23** (partial) deliberately still fails, so a new
  unreadable path is loud.
- The `if [ "$?" = 0 ]` after the error check is always true, so the
  `-failed-` rename is unreachable. Known and left alone.
- The rsync `--log-file` uses `--log-file-format=''` so it holds only the
  `--stats` summary.

## Excludes

- `.config/backup_exclude` is a deny-list; do not invert it to an allow-list.
- Write patterns **by class** (`**/target/debug/`, `**/.venv/`), not by path.
- `+ ` lines are includes, first match wins. A carve-out from a blanket
  exclude needs its parent dirs included first and an explicit `- /parent/*`
  after. Verify by dry run.
- A pattern with no interior slash matches at any depth: anchor with a
  leading `/`.
- `backup-audit` (weekly) diffs a dry run against its baseline and notifies
  on growth past `BACKUP_AUDIT_THRESHOLD`. `.rsync-filter` files are the
  per-directory escape hatch.

## The NAS side

- `authorized_keys` carries `restrict,from="192.168.42.0/23"`. **The LAN is a
  /23**: a /24 locks out half the hosts. `command=` is ruled out (the script
  needs arbitrary remote commands, and beedle has no perl for `rrsync`).
- Hold a `ControlMaster` open while editing `authorized_keys`; the old line
  is in `~/.ssh/authorized_keys.bak` on beedle.
- **`backup` must stay in `administrators`**: DSM allows SSH only to that
  group. Per-user Deny rules neutralise it.
- Immutable Btrfs snapshots of the `backup` share (Snapshot Replication, WORM)
  are what protect against a stolen key deleting everything. They pin
  deleted extents until they expire.

## Indicator and browser

- The shell watches `status.json` only. A `FileView` watch on a missing file
  never fires when it appears, so it retries every 30s; the watch survives
  `os.replace`. A stale `running` record is checked against `systemctl
  is-active`.
- The browser is its own quickshell process (`backups.qml`, launched by
  `backup-browser` via `I3.dispatch("exec …")`, raised over its own IPC).
  Every read goes through `backup-browse` in a `Process`, **serialised**,
  never restarted.
- Both `ListView`s set `keyNavigationEnabled: false` and the content item
  takes focus, or the list eats the arrow keys.
- "Changed" means size and whole-second mtime differ from the next-older
  snapshot (rsync's own quick check). Inode numbers are not stable over SMB.
  "Previous" is by full-resolution mtime.
- Restore: keep-both writes `name (backup YYYY-MM-DD).ext`; replace on a
  directory is `rsync -a --delete`.
- Test read-only-ness with an actual `open(O_CREAT)` (`EROFS`), never `test
  -w`.
