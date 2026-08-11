---
name: release
description: Cut a TransPaste release — version bump PR, then a tag push that triggers the automated publish workflow. Use when asked to release, tag, or publish a version.
---

# Release TransPaste

Publishing is automated: pushing a `v*` tag runs `.github/workflows/release.yml`
(verify tag↔version → test → build → codesign verify → zip + sha256 →
GitHub release with auto-generated notes + install footer).

1. **Preconditions**: on `main`, clean tree, latest `main` CI run green
   (`gh run list --branch main --limit 1`).
2. **Bump the version** in `Sources/AppInfo.swift` AND the repo-root
   `Info.plist` (a test asserts they match; build.sh injects into the bundle):
   - PATCH: fixes, docs, internal refactors
   - MINOR: new user-visible features (new provider, new menu item)
   - MAJOR: breaking changes (bundle ID change, providers.json format change)
3. **Verify**: `./test.sh` && `./build.sh` && `swift build`.
4. **Ship the bump** via a PR (see the `ship` skill) — never commit to `main`.
5. **Tag after merge** — this is the entire publish step:
   ```
   git checkout main && git pull
   git tag v<version> && git push origin v<version>
   ```
6. **Watch it**: `gh run watch $(gh run list --workflow Release --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status`,
   then `gh release view v<version>` to confirm the artifacts
   (`TransPaste-<version>.zip` + `.sha256`) and notes.
7. The workflow **fails the release if the tag doesn't match AppInfo.version** —
   that's the guard against tagging an unbumped main; fix the version, merge,
   re-tag.
8. Auto-notes group PRs by label (`.github/release.yml`) — label PRs
   feature/bug/ci as you go. If the bundle ID or signing changed, edit the
   release notes to call out the permission re-grant.
