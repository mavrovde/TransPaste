---
name: ship
description: TransPaste's implement → test → deploy workflow. Use when finishing a feature, preparing a PR, or asked to "ship" a change.
---

# Ship a TransPaste change

Follow every step; CI mirrors steps 2–4, so local failures will fail the PR.

1. **Branch** from `main` — never commit to `main` directly.
2. **Test**: `./test.sh` — all tests must pass. New code needs tests in the
   TestKit harness (no XCTest — it doesn't exist on this machine). Filter with
   `./test.sh "name substring"` while iterating.
3. **Build both ways**: `./build.sh` (the real .app bundle + ad-hoc codesign)
   and `swift build` (keeps Package.swift honest; CI doesn't run it).
4. **Docs in the same PR**: update README.md and CLAUDE.md when behavior,
   menus, models, or keys changed. Bump UserDefaults key suffixes on semantic
   changes. Append new learnings to `.claude/KNOWLEDGE.md`.
5. **PR**: push the branch, `gh pr create` with a label that exists
   (feature/fix/ci/tooling/bug/enhancement — `--label` hard-fails and aborts PR
   creation on unknown labels; release notes group by them). Then watch CI to
   green — but poll `gh pr checks <n>` until it succeeds before
   `gh pr checks <n> --watch --fail-fast`: run immediately it exits with
   "no checks reported" because the first check hasn't registered yet.
   Stages: Build → Test → Package, plus CodeQL (manual build mode — never
   re-enable default setup).
6. **Merge & verify**: after merge, confirm the push-to-`main` CI run is green.
7. **Deploy** = users run `./build.sh` + `open build/TransPaste.app`. If the
   bundle ID or signing changed, the release notes must tell users to re-run
   `./automated_setup.sh` (TCC grants are identity-bound).
8. Manually smoke-test the hotkey → translate → paste flow when InputMonitor,
   AppDelegate timing, or permissions code changed — that path has no
   automated coverage.
