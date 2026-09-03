# Code comments

Do not add code comments explaining why a change is being made (e.g. "this was
moved out of Redux because...", "must be memoized otherwise..."). Only add
comments explaining WHAT code does, and only when the code is particularly
confusing.

**Why:** Such comments go stale; Andy strips them during review.

**How to apply:** When editing code, express intent through naming and structure
instead of rationale comments. Put the "why" in the commit message or the chat
summary, never in the code.
