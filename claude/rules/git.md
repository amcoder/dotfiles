# Commits

Work through a task without committing, and make a single commit once we agree
it is done. One commit per unit of work, not a trail of fixes.

**Why:** A trail preserves reasoning that later turned out to be wrong. A small
feature took six commits, and one of them recorded a colour-matrix tag as
"measured rather than assumed" while the next had to retract it. Held to the
end, that would have been a wrong turn during the work rather than a false
claim in the permanent record.

**How to apply:** Do not commit mid-investigation. Do not write a mechanism
into a commit message until the investigation has settled — if a claim might
still be retracted, it is not ready to be recorded. Where a session genuinely
produces separate units of work, commit each separately rather than bundling
them. Stage by path: this repo usually has unrelated live churn in the working
tree, so `git commit -a` is always wrong here.
