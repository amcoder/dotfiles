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

# Rebase, don't merge

Prefer rebase over merge wherever it is possible without rewriting history
that is already on the remote. The one exception is a PR branch: its history
is allowed to change, so rebasing it — onto its base branch, or to squash and
reorder its own commits — is fine even after it has been pushed.

**Why:** A merge commit records the act of integrating rather than a unit of
work, and a branch stitched together with them is hard to read, bisect and
revert. Rewriting shared history is worse, because everyone tracking that
branch then has to recover, so the line is drawn at what has been pushed to a
branch other people build on.

**How to apply:** When a PR has conflicts, rebase it onto its base branch and
resolve them there rather than merging the base branch in. Bring a local
branch up to date with `git pull --rebase`, never a merge. A branch that has
been pushed is still fair game if it is a PR branch (force-push with
`--force-with-lease`); `master`/`main` and any other shared branch are not —
never rewrite those, and if a merge is the only way to bring one forward,
merge.
