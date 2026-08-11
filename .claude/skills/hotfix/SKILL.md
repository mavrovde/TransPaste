---
name: hotfix
description: Fast-path a critical TransPaste fix into a patch release. Use for broken-for-users bugs that can't wait for the normal cycle.
---

# Hotfix → patch release

Same quality gates as `ship`, compressed timeline — never skip tests.

1. Branch from current `main`: `git checkout -b hotfix/<slug> main`.
   (If `main` has unreleased risky changes, branch from the last tag instead
   and note that the patch release won't include them.)
2. Make the **minimal** fix — no drive-by refactors, no doc rewrites beyond
   the fix itself. Add a regression test that fails without the fix.
3. Bump PATCH in `Sources/AppInfo.swift` + root `Info.plist` in the same PR.
4. `./test.sh && ./build.sh && swift build` — all green locally.
5. PR with a `bug` label (release notes categorize it), get CI green, merge.
6. Tag immediately: `git checkout main && git pull && git tag v<X.Y.Z+1> && git push origin v<X.Y.Z+1>`.
7. Watch the Release workflow, then run the `verify-release` skill.
8. If the bug corrupted user state (providers.json, UserDefaults), the release
   notes must include recovery steps (usually: delete the file, it regenerates).
9. Post-mortem line in `.claude/KNOWLEDGE.md`: what broke, why tests missed it,
   which test now covers it.
