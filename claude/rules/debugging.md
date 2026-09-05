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

# Establish that a test can see the difference

Before trusting a comparison, check that it has the power to detect what it
claims to. A number from a test that cannot separate the hypotheses is noise,
not evidence, however carefully it was produced.

**Why:** A whole-frame colour average "showed" a video was already BT.709, and
that tag was shipped and described in the commit message as measured. It was
noise: on dark desktop content BT.601 and BT.709 predict luma less than 3
apart, so the average could not tell them apart at all. The test with power was
the Y plane, which 4:2:0 does not subsample, on deliberately colourful content
— and it said the opposite.

**How to apply:** Name the discriminating quantity and check it *before*
measuring — how far apart do the hypotheses predict the result, and is that
above the noise floor? Prefer a control that should fail: an A/B whose two
sides come out mirror images is trustworthy in a way a single number is not.
Check the test artifact too, asserting it has the properties you intended
before analysing it, since a broken harness reports plausible wrong numbers
instead of failing — a stray shell quoting bug silently dropped a flag, and an
off-by-one frame width turned a clean result into an apparent catastrophe.
