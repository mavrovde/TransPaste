---

## Installation

1. Download `TransPaste-<version>.zip` below and unzip it (verify with the `.sha256` file if you like).
2. The app is ad-hoc signed, so macOS Gatekeeper will warn on first launch of a downloaded copy. Either right-click → **Open** once, or clear the quarantine flag:
   ```
   xattr -d com.apple.quarantine TransPaste.app
   ```
3. Grant **Accessibility** and **Input Monitoring** permissions (the app guides you, or run `./automated_setup.sh` from a source checkout).
4. Pick your AI provider and paste its API key from the menu bar icon. Local Ollama needs no key.

> **Upgrading?** If this release changed the bundle ID or signing (check the notes above), re-grant permissions via System Settings or `automated_setup.sh`.
