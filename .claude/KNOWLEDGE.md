# TransPaste — Project Knowledge Base

Accumulated experience, known issues, and proven workflows. Read this before
debugging build, permission, or CI problems.

## Hard-won constraints

### No XCTest on dev machines (Command Line Tools only)
- `xcode-select -p` → `/Library/Developer/CommandLineTools`; XCTest and the
  Swift `Testing` module do not exist anywhere on disk.
- The original XCTest suite **never compiled** here — it silently rotted.
- Solution: self-contained harness in `Tests/TestKit.swift`, run via
  `./test.sh`. Never reintroduce `import XCTest` or an SPM `testTarget`.
- Async test assertions use run-loop spinning (`waitUntil`), never semaphores —
  completions may hop to the main queue and a semaphore wait deadlocks.

### macOS TCC permissions are bound to code-signing identity
- The ad-hoc `codesign` step in `build.sh` is load-bearing: it stabilizes the
  bundle identity so Accessibility/Input Monitoring grants survive rebuilds.
- Changing `CFBundleIdentifier` (currently `com.mavrovde.transpaste`)
  invalidates all existing grants — users must re-run `./automated_setup.sh`.
- The hotkey/capture flow cannot be unit-tested (needs real TCC grants and a
  focused target app) — always verify manually via the built .app.

### Focus/timing choreography is deliberate
- The `asyncAfter` delays in `InputMonitor` and the 0.5s pause between hiding
  the app and pasting exist because paste-back depends on macOS returning
  focus to the original app. Do not "clean up" delays without manually testing
  hotkey → paste end-to-end.
- `isMacroRunning` guards hotkey re-entrancy — every exit path must reset it.

### Swift 6 language mode is a known migration debt
- `Package.swift` uses tools-version 6.0 with `swiftLanguageMode(.v5)` pinned:
  strict concurrency produces ~17 errors in the AppKit/Carbon code
  (main-actor isolation on NSAlert/NSApplication calls). Migrate deliberately,
  not as a side effect of a version bump.

## CI / GitHub facts

- CI (`.github/workflows/ci.yml`): Build (bundle + `codesign --verify`) →
  Test (`./test.sh`) → Package (zipped `TransPaste.app` + DMG installer artifacts). All stages
  run on `macos-latest`; whole pipeline ~1.5 min.
- **CodeQL default setup hangs forever on this repo** — its Swift autobuilder
  guesses xcodebuild/SPM and never finishes against our swiftc build. We use
  advanced setup (`.github/workflows/codeql.yml`) with `build-mode: manual`
  running `./build.sh`. Never re-enable default setup.
- GitHub's "Code scanning AI findings" check has failed before with
  `CAPIError: 400 The requested model is not supported` — that is GitHub's
  backend, not our code. Don't debug it here.
- Dependabot covers `github-actions` and `swift` ecosystems weekly.
- **macOS runner pool is tiny (personal account ~5 concurrent)** and a CodeQL
  Swift scan holds one for ~30 min. Uncancelled/duplicate scans once starved
  CI Build jobs into an indefinite queue. Rules now enforced in codeql.yml:
  paths filter (Swift/build inputs only), concurrency cancel-in-progress,
  weekly full scan. If Build sits "queued" for many minutes, suspect runner
  starvation — `gh run list` and cancel redundant scans first.
- The app icon is **generated as code** (`tools/generate_icon.swift`, AppKit
  drawing → iconset → `iconutil` → `build/AppIcon.icns`, cached; build.sh
  regenerates when missing). No binary image assets in the repo — edit the
  Swift file to change the design, delete `build/AppIcon.icns` to force
  regeneration. Preview renders can be visually checked by Reading a PNG.
- Release publishing is `.github/workflows/release.yml` on `v*` tags: guard
  (tag == AppInfo.version) → test → signed build → zip + DMG (`package_dmg.sh`:
  app + /Applications symlink, UDZO) + sha256s → release with generated notes.
  v1.1.0/v1.2.0 published via this pipeline (zip-only, pre-DMG); the DMG ships starting v1.3.0 — all verified end-to-end.

## Provider integration notes (TranslationService)

- API keys travel in **headers only** (never URLs — proxies log URLs):
  Gemini `x-goog-api-key`, OpenAI `Authorization: Bearer`,
  Claude `x-api-key` + `anthropic-version: 2023-06-01`.
- Claude (`claude-opus-5`): thinking is on by default, so responses contain
  thinking blocks **before** the text block — parse by `type == "text"`,
  never `content[0]`. `max_tokens` is required. `stop_reason == "refusal"`
  must be handled before reading content. `output_config.effort: "low"`
  keeps hotkey latency down.
- Gemini: candidates blocked by safety filters arrive without `content` —
  all levels of that decode path are optional.
- **Endpoints/models are never hardcoded in request code** — they resolve from
  `~/.transpaste/providers.json` (commented JSON, auto-created from the
  template in `ProviderConfig`, which is the single source of defaults).
  `{model}` in an endpoint is substituted at request time. Tests pin
  `ProviderConfig.configURL` to a temp path in `TestMain` — keep it hermetic.
- **Ollama** and **Custom** are key-less (`requiresAPIKey == false`); both speak
  OpenAI Chat Completions. Custom's menu dialog overrides (UserDefaults
  `CustomEndpointV1`/`CustomModelV1`) take precedence over providers.json.
- Adding a provider = one enum case + one request/response struct pair +
  tests; see `.claude/skills/add-provider/SKILL.md`. Check OpenAI-compatibility
  first — the Custom provider may already cover it.

## Project tooling map

- Agents: `swift-reviewer` (pre-PR review vs repo constraints), `ci-doctor`
  (failing/stuck workflow runs), `docs-sync` (docs vs code truthfulness),
  `release-manager` (release gates: preflight, tag, post-publish validation),
  `dependabot-triage` (dependency PRs: breaking-change mapping, missed-file
  sweeps, safe merge).
- Skills: `ship` (implement→test→PR→green), `release` (bump PR → tag →
  automated publish), `verify-release` (assets/checksum/signature/version
  audit), `hotfix` (minimal fix → patch release fast path), `add-provider`,
  `bump-models` (default model/endpoint refresh), `troubleshoot` (runtime
  symptom→fix map).
- Plugins (project-enabled): context7 (live API docs — use for provider model
  drift), code-review, commit-commands, claude-md-management.

## Workflow: implement → test → deploy

1. Branch from `main` (never commit to `main` directly).
2. Implement; keep UserDefaults keys version-suffixed when semantics change.
3. `./test.sh` (all tests) and `./build.sh` (bundle) locally — both must pass.
4. `swift build` too — CI doesn't run it, but Package.swift must stay valid.
5. Update README + CLAUDE.md in the same PR when behavior changes.
6. Push, open PR, wait for CI green (Build → Test → Package) + CodeQL.
7. Merge; post-merge CI on `main` must also go green.
8. Semver convention (user-set): cosmetic = PATCH (icon, wording); MINOR only
   for functional features. A mistagged unpublished release is recoverable:
   cancel the Release run, delete the tag (git push origin :refs/tags/vX),
   re-version via PR, re-tag (done for the aborted v1.4.0 → v1.3.1).
9. Release = tag push (`git tag v<X.Y.Z> && git push origin v<X.Y.Z>`) —
   `.github/workflows/release.yml` tests, builds, packages (zip + DMG + sha256s), and
   publishes the GitHub release with generated notes (categories from
   `.github/release.yml`, install footer from `.github/RELEASE_FOOTER.md`).
   The workflow fails if the tag doesn't match `AppInfo.version`. If the
   bundle ID/signing changed, note the permission re-grant in the release.
