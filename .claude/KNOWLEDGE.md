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
  Test (`./test.sh`) → Package (zipped `TransPaste.app` artifact). All stages
  run on `macos-latest`; whole pipeline ~1.5 min.
- **CodeQL default setup hangs forever on this repo** — its Swift autobuilder
  guesses xcodebuild/SPM and never finishes against our swiftc build. We use
  advanced setup (`.github/workflows/codeql.yml`) with `build-mode: manual`
  running `./build.sh`. Never re-enable default setup.
- GitHub's "Code scanning AI findings" check has failed before with
  `CAPIError: 400 The requested model is not supported` — that is GitHub's
  backend, not our code. Don't debug it here.
- Dependabot covers `github-actions` and `swift` ecosystems weekly.

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

## Workflow: implement → test → deploy

1. Branch from `main` (never commit to `main` directly).
2. Implement; keep UserDefaults keys version-suffixed when semantics change.
3. `./test.sh` (all tests) and `./build.sh` (bundle) locally — both must pass.
4. `swift build` too — CI doesn't run it, but Package.swift must stay valid.
5. Update README + CLAUDE.md in the same PR when behavior changes.
6. Push, open PR, wait for CI green (Build → Test → Package) + CodeQL.
7. Merge; post-merge CI on `main` must also go green.
8. "Deploy" = users pull and run `./build.sh`; if the bundle ID changed,
   the release notes must say to re-run `./automated_setup.sh`.
