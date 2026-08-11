# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**TransPaste** — a macOS menu bar app (Swift, AppKit, no Xcode project) that captures selected text via a global hotkey (`Ctrl+Cmd+T`), translates it with the selected AI provider (Gemini, OpenAI, Claude, local Ollama, or any custom OpenAI-compatible endpoint), and pastes the result back into the active app. Requires macOS 13+. Repo is `mavrovde/TransPaste`; the app/bundle name is TransPaste.

## Commands

```bash
./build.sh          # Compiles Sources/*.swift with swiftc -O into build/TransPaste.app, copies Info.plist, ad-hoc codesigns
./test.sh           # Compiles and runs the full test suite
./test.sh "API key" # Run only tests whose name matches the filter (case-insensitive substring)
./package_dmg.sh    # Builds build/TransPaste-<version>.dmg (drag-to-Applications installer; runs build.sh if needed)
swift build         # SPM build (bare executable in .build/ — not an .app bundle, permissions won't work)
open build/TransPaste.app          # Launch (menu bar icon only; LSUIElement=true, no Dock icon)
./automated_setup.sh # Resets TCC permissions (tccutil) and guides re-granting Accessibility + Input Monitoring
tail -f ~/translator.log           # All runtime logging goes here
```

## Testing — important constraints

- **XCTest is NOT available on this machine** (Command Line Tools only, no Xcode). Tests use a self-contained harness in `Tests/TestKit.swift` (`test`/`expect`/`expectEqual`/`waitUntil` functions) and run as a plain executable via `./test.sh`. Do not add `import XCTest` or an SPM testTarget — neither will compile here.
- `test.sh` compiles all Sources **except `main.swift`** (its top-level code conflicts with the test runner's `@main` in `Tests/TestMain.swift`) plus `Tests/*.swift`. New test files need a `runXxxTests()` function called from `TestMain.main()`.
- Async assertions use `waitUntil` (run-loop spinning), never semaphores — completions may hop to the main queue and a semaphore wait would deadlock.
- Network paths are tested with `MockURLProtocol` (in `TranslationServiceTests.swift`) injected via `TranslationService(session:)`.
- Key-absence tests auto-skip when `OPENAI_API_KEY` is set in the environment — a "Skipped" line in test output is expected, not a failure.
- The hotkey/capture macro can't be unit-tested (needs real TCC permissions and a focused target app) — verify that flow manually via the built .app.

## Architecture

Six source files, one flat module, no dependencies:

- `main.swift` → creates `NSApplication` with `AppDelegate`.
- `AppDelegate` — menu bar UI, language prefs, permission prompts, dialog flow. Implements `InputMonitorDelegate.triggerTranslation`: confirmation dialog → `TranslationService` → result dialog → hides the app (restores focus to the target app) → completion with text to paste.
- `InputMonitor` — hotkey via **Carbon** `RegisterEventHotKey` (not NSEvent monitors); `start()` is idempotent (guards re-registration — "Check Permissions" in the menu calls it again). Capture: Accessibility API (`kAXSelectedTextAttribute`) first, then synthetic Cmd+A/Cmd+C with clipboard polling. `isMacroRunning` guards re-entrancy — every exit path must reset it.
- `TranslationService` — multi-provider REST client. `TranslationProvider` enum (gemini/openai/claude/ollama/custom) carries per-provider model, endpoint, headers, env var, and UserDefaults key; wire-format Codable structs live alongside. Endpoints/models resolve from `~/.transpaste/providers.json` via `ProviderConfig` (commented JSON; the in-code template is the default source; tests pin `configURL` to a temp path). Default models: `gemini-flash-latest`, `gpt-5-mini`, `claude-opus-5`, `llama3.2` (Ollama/custom, key-less) (with `output_config.effort: low`; thinking blocks precede the text block in Claude responses — parse by block type, never `content[0]`). API keys go in headers (`x-goog-api-key` / `Authorization: Bearer` / `x-api-key` + `anthropic-version`), **never in URLs**. Key resolution per provider: env var (`GEMINI_API_KEY`/`OPENAI_API_KEY`/`ANTHROPIC_API_KEY`), then UserDefaults. Selected provider persists in UserDefaults `TranslationProviderV1`. Injectable `URLSession` for tests.
- `Logger` — singleton appending to `~/translator.log`; writes are serialized on a private queue; `flush()` blocks until pending writes land (tests rely on it).

The `asyncAfter` delays in the macro and the 0.5s pause between hiding the app and pasting are focus-restoration timing, not cruft — don't remove them without manually testing hotkey → paste end-to-end.

## Conventions and gotchas

- **UserDefaults keys are version-suffixed** (`SourceLanguageV3`, `TargetLanguageV3`, `IsTranslationEnabledV2`, `TranslationProviderV1`) — bump the suffix when changing a preference's default/semantics rather than migrating values.
- **Ad-hoc code signing in build.sh is load-bearing**: it stabilizes bundle identity so TCC grants survive rebuilds. Changing `CFBundleIdentifier` (`com.mavrovde.transpaste`) invalidates existing grants — users must re-run `./automated_setup.sh`.
- CI (`.github/workflows/ci.yml`) runs build → test → package stages on macOS runners; package uploads the zipped `TransPaste.app` and the DMG installer as artifacts. Releases (`v*` tags) publish DMG + zip + sha256s automatically.

- Project agents, skills, and the accumulated known-issues knowledge base live in `.claude/` — read `.claude/KNOWLEDGE.md` before debugging build, permission, or CI problems.
