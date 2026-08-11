# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"on-fly-translator" — a macOS menu bar app (Swift, AppKit, no Xcode project) that captures selected text via a global hotkey (`Ctrl+Cmd+T`), translates it with the Google Gemini API, and pastes the result back into the active app. Requires macOS 13+, Swift 5.9+.

## Commands

```bash
./build.sh          # Compiles Sources/*.swift with swiftc -O into build/on-fly-translator.app, copies Info.plist, ad-hoc codesigns
./test.sh           # Compiles and runs the standalone test binary (see caveats below)
swift build         # SPM build (outputs to .build/, not an .app bundle)
swift test          # Run tests via SPM
open build/on-fly-translator.app   # Launch (menu bar icon only; LSUIElement=true, no Dock icon)
./automated_setup.sh # Resets TCC permissions (tccutil) and guides re-granting Accessibility + Input Monitoring
tail -f ~/translator.log           # All runtime logging goes here
```

### test.sh caveats

- It **generates** `Tests/RunTests.swift` and `Tests/LinuxMain.swift` on every run — these are throwaway artifacts, don't edit them.
- It only compiles `GoogleGeminiService.swift` + `Logger.swift` + `GoogleGeminiServiceTests.swift` and only runs the two tests explicitly registered by selector in the generated `RunTests.swift` (`testRequestCreation`, `testMissingAPIKeyError`). `InputMonitorTests` and `LoggerTests` exist but are NOT run by test.sh. New tests must be added to the suite registration in test.sh, or run via `swift test` instead.
- To run a single test, edit which `suite.addTest(...)` lines test.sh generates, or use `swift test --filter <TestClass>/<testMethod>`.

## Architecture

Five source files, one flat module, no external dependencies:

- `main.swift` → creates `NSApplication` with `AppDelegate`.
- `AppDelegate` — menu bar UI, language prefs, permission prompts, and the dialog flow. Implements `InputMonitorDelegate.triggerTranslation`: shows the "Translate this text?" confirmation, calls `GoogleGeminiService`, shows the result dialog, then hides the app (to restore focus to the target app) before invoking the completion with the text to paste.
- `InputMonitor` — registers the hotkey via the **Carbon** `RegisterEventHotKey` API (not NSEvent monitors). On trigger, tries the Accessibility API (`kAXSelectedTextAttribute`) first; falls back to a synthetic-keystroke macro (Cmd+A, Cmd+C with clipboard polling/retries), then hands captured text to the delegate. After the delegate confirms, it puts the translation on the pasteboard and posts Cmd+V. A `isMacroRunning` flag guards against re-entrant hotkey triggers — every completion path must reset it.
- `GoogleGeminiService` — REST client for the Gemini `generateContent` endpoint (model `gemini-flash-latest`). Accepts an injectable `URLSession` for testing; `makeRequest` is public specifically so tests can inspect request construction.
- `Logger` — thread-unsafe-but-simple singleton appending to `~/translator.log`. All components log through it; it's the primary debugging tool since the app has no console.

The timing-sensitive parts (macro delays, clipboard polling, the 0.5s pause between hiding the app and pasting) exist because paste-back depends on macOS focus returning to the original app — don't "clean up" the `asyncAfter` delays without testing the full hotkey → paste flow manually.

## Conventions and gotchas

- **API key resolution order**: `GEMINI_API_KEY` env var, then UserDefaults key `GeminiAPIKey` (set via the menu's "Paste API Key from Clipboard").
- **UserDefaults keys are version-suffixed** (`SourceLanguageV3`, `TargetLanguageV3`, `IsTranslationEnabledV2`) — bump the suffix when changing a preference's default/semantics rather than migrating values.
- **Ad-hoc code signing in build.sh is load-bearing**: it stabilizes the bundle identity so macOS TCC permission grants (Accessibility, Input Monitoring) survive rebuilds. If permissions break after a rebuild, run `./automated_setup.sh`.
- The hotkey and macro behavior can't be meaningfully verified in unit tests — they need real Accessibility/Input Monitoring permissions and a focused target app. Test manually via the built .app.
