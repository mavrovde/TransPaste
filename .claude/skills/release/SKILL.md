---
name: release
description: Cut a TransPaste release — version bump, tag, GitHub release with the app artifact. Use when asked to release, tag, or publish a version.
---

# Release TransPaste

1. **Preconditions**: on `main`, clean tree, latest `main` CI run green
   (`gh run list --branch main --limit 1`).
2. **Bump the version** in `Sources/AppInfo.swift` only (single source; build.sh
   injects it into the bundle's Info.plist, and a test checks the repo-root
   Info.plist matches — update that file too):
   - PATCH: fixes, doc-only, internal refactors
   - MINOR: new user-visible features (new provider, new menu item)
   - MAJOR: breaking changes (bundle ID change, config format change)
3. **Verify**: `./test.sh` && `./build.sh` && `swift build`.
4. **Changelog entry**: summarize since the last tag
   (`git log $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD --oneline`).
5. **Ship the bump** via a PR (see the `ship` skill) — never commit to `main`.
6. **Tag + release** after merge:
   ```
   git checkout main && git pull
   git tag v<version> && git push origin v<version>
   ./build.sh && ditto -c -k --keepParent build/TransPaste.app build/TransPaste.app.zip
   gh release create v<version> build/TransPaste.app.zip --title "TransPaste <version>" --notes "<changelog>"
   ```
7. **Release notes must warn** about `./automated_setup.sh` re-run if the bundle
   ID or signing changed since the user's previous version.
