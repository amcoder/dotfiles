# Where a new instruction belongs

`~/.claude/CLAUDE.md` is the machine-specific half of Andy's global
instructions and is not tracked anywhere. The shared half is
`~/.dotfiles/claude/rules/*.md`, symlinked into `~/.claude/rules/` and loaded
into every session exactly as `CLAUDE.md` is.

Before writing an instruction to `~/.claude/CLAUDE.md`, decide which half it
belongs to, and say which you chose:

- **Shared** — it would hold on any machine Andy works on. Add it to an
  existing file under `~/.dotfiles/claude/rules/`, or add a new one there.
  A new file needs `./install` re-run to create its symlink before it loads.
- **Machine-specific** — it names this host's hardware, paths outside the
  dotfiles, or a one-off local setup. That belongs in `~/.claude/CLAUDE.md`.

When in doubt it is shared: a rule that turns out to be local is easy to move
back, while one that stays here is silently missing from every other machine.
