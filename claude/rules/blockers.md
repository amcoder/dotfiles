# When you need something only Andy can provide

If the work needs a package installed, an awake screen, a credential, or
anything else you cannot arrange yourself, say so and wait. Do not build a
workaround.

**Why:** Working around a blocker costs more than asking, and it can produce
wrong answers rather than no answer. Downloading a .deb and chasing five
library dependencies to avoid asking for one `apt install` meant maintaining
stub binaries in `~/.local/bin` for the rest of the session, one of which would
have silently shadowed the real one once it was installed. Measuring against an
idle-blanked screen was worse: it did not fail, it returned numbers — "16.00
for both", then "0.000 for both" — that had to be recognised as meaningless.

**How to apply:** Ask in one sentence, naming the exact command where there is
one, and get on with whatever does not depend on it. If a check needs the
environment in a particular state and you cannot put it there, verify that
precondition and stop rather than measuring anyway.
