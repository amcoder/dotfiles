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

# Commit messages and PR descriptions

Write them in Andy's voice: a short imperative subject, then at most a
paragraph or two saying what the problem was and what the change does about
it. Nothing about how the answer was reached.

**Why:** Generated messages have run to five or six paragraphs recording every
measurement, rejected theory and dead end from the session. That is the story
of the work, not a description of the change, and it buries the one sentence a
reader of `git log` wants.

**How to apply:** Subject under about 70 characters, no trailing full stop, no
prefix. Body only when the subject does not cover it: plain prose, problem
then fix, plus anything non-obvious the diff cannot show in a line. Leave out
the investigation, what was tried first, and what was measured along the way;
if any of that is worth keeping it belongs in the repo's CLAUDE.md or the chat
summary. A commit from Andy's own log for calibration:

    Add a C# rule for XML documentation comments

    Comments on classes, methods and properties in .cs files are /// XML doc
    comments rather than // above the member. Scoped with paths: to **/*.cs
    so it costs no context outside C# work.

PR descriptions follow the same shape: what was wrong, what this does, and a
line on how it was verified if that is not obvious. No section headings, no
bullet lists of every file touched.
