---
paths:
  - "system/mounts/**"
  - "system/install-mounts"
---

# NAS mounts

`//beedle/media` and `//beedle/backup` are CIFS automounts at
`~/beedle/{media,backup}`, unmounted after 10 minutes idle. How each rule here
was established is in `.claude/nas-mounts-reference.md`; read the relevant part
there before changing a mechanism described here.

- Root-owned files in `/etc`, **copied, not linked**:
  `sudo ./system/install-mounts` after any edit. It also writes the credential
  template, reloads and enables the `.automount` units.
- Never mount a network filesystem at login: an `.automount` nobody touches
  cannot fail, and one that is touched retries.
- A `.mount` unit's name must be the escaped `Where=` (checked with
  `systemd-escape --path --suffix=`). The idle timeout is `TimeoutIdleSec` in
  `[Automount]`; `x-systemd.idle-timeout` is fstab-only. The installer does not
  create the mount points (they would be root-owned).
- CIFS options: `uid=1000,gid=1000`, `soft`, `actimeo=30`, `mfsymlinks`. The
  password is in `/etc/cifs/beedle.cred` (0600, never in the repo).
- autofs triggers on a **stat** of the mount point, so `ls -l ~` and a search
  rooted at `$HOME` touch the NAS. `/mnt/beedle/*` plus symlinks is the way out
  if that bites.
- A connection reset **before the SSH banner** is not authentication: it is
  DSM's Auto Block. Test with a raw socket that sends nothing. SSH refused while
  the DSM web UI answers is evidence for the block.
- The block was earned by `Host * IdentityAgent` offering every agent key.
  `~/.ssh/config` (untracked) pins `IdentitiesOnly yes` and one `IdentityFile`
  per NAS host, pointing at a `.pub` to pick a key from the agent. Count
  `Offering public key` lines with the jump host quieted.
