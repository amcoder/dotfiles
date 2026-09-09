# Where the common tools live

Several toolchains are installed outside the usual places:

- **mssql-tools** (`sqlcmd`, `bcp`) — `/opt/mssql-tools18/bin`
- **Go** — `GOPATH` is `~/.local/share/go`; `go install` binaries land in
  `~/.local/share/go/bin`
- **Rust** — `CARGO_HOME` is `~/.local/share/cargo` and `RUSTUP_HOME` is
  `~/.local/share/rustup`; `cargo`, `rustc`, `rustup` and everything
  `cargo install` builds are in `~/.local/share/cargo/bin`
- **node / npm / npx** — nvm's `NVM_DIR` is `~/.local/share/nvm`, with each
  version under `~/.local/share/nvm/versions/node/<version>/bin`

**Why:** sessions have failed to find these and concluded the tool was not
installed.

**How to apply:** a tool missing from `$PATH` is not evidence it is missing from
the machine — look in the directories above before saying anything about it.
`~/.profile` adds each of them with a `[ -d ]` guard and runs once at login, so
a toolchain installed since then is absent from a running session's `PATH`
until the next one; that is exactly why `/opt/mssql-tools18/bin` can be missing
while `sqlcmd` is sitting in it. nvm itself is sourced only by interactive zsh,
so a non-interactive shell needs `. "$NVM_DIR/nvm.sh"` before `nvm use`, or the
version's `bin` directory named directly.

If what you need genuinely is not on the machine, ask Andy to install it rather
than improvising around its absence — see `blockers.md`.
