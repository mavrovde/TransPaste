---

## Installation

**DMG (recommended):** download `TransPaste-<version>.dmg`, open it, and drag **TransPaste** onto the **Applications** shortcut. Eject the disk image.

**Zip:** download and unzip `TransPaste-<version>.zip`, move `TransPaste.app` wherever you like. (`.sha256` files are provided to verify either download.)

Then:

1. The app is ad-hoc signed, so macOS Gatekeeper warns on first launch of a downloaded copy. Right-click → **Open** once, or clear the quarantine flag:
   ```
   xattr -d com.apple.quarantine /Applications/TransPaste.app
   ```
2. Grant **Accessibility** and **Input Monitoring** permissions (the app guides you, or run `./automated_setup.sh` from a source checkout).
3. Pick your AI provider from the menu bar icon — if it needs an API key, the app offers to paste one right away. Local Ollama needs no key.

> **Upgrading?** If this release changed the bundle ID or signing (check the notes above), re-grant permissions via System Settings or `automated_setup.sh`.
