# Diagnosing problems

When the cause of a bug or a slowdown is not yet established, find the exact
mechanism before proposing a fix. Do not apply a bundle of plausible fixes and
hope one lands.

**Why:** Shotgun fixes get shipped without evidence and are often simply wrong.
Chasing a slow login screen, the three-variable shotgun measured 25.10s against
a 25.14s baseline — no effect at all; only an A/B harness found the real cause.

**How to apply:** Say plainly which claims are measured and which are inferred.
Prefer building an isolated reproduction that can A/B candidates and report
numbers, over reasoning to a single answer. Wrong theories along the way are
fine; presenting one as settled is not. A shotgun fix may be offered, but label
it as a shortcut trading certainty for time — never as the recommendation. When
instrumenting something that is also a recovery path, verify the instrumentation
works before it becomes the only way in.
