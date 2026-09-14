---
paths:
  - "**/*.cs"
---

# C# documentation comments

Comments on classes, methods and properties are XML documentation comments
(`/// <summary>…</summary>`, with `<param>`, `<returns>`, `<typeparam>` and
`<exception>` where they apply), not `//` or `/* */` comments above the member.

**Why:** The compiler, IntelliSense and doc generators read `///` comments;
a plain `//` above a member is invisible to all of them and inconsistent with
the surrounding code.

**How to apply:** Applies to what a comment *is*, not whether to write one —
the rule in `comments.md` still decides that. Keep the summary to what the
member does; inline `//` comments inside a method body are unaffected.
