import Foundation

/// Every user-facing message in one place so tests can verify each is
/// present, actionable, and correctly parameterized (Tests/MessagesTests.swift).
/// Menu item titles stay in AppDelegate (they're structural); dialogs,
/// warnings, and buttons live here.
public enum UserMessages {

    // MARK: Permissions

    public static let permissionRequiredTitle = "Permission Required"
    public static let permissionRequiredText = """
        TransPaste needs Accessibility permission to copy the selected text and paste the translation back.

        1. Click "Open Settings" below.
        2. Enable TransPaste in the list.

        No relaunch needed — TransPaste detects the permission automatically.
        """
    public static let openSettingsButton = "Open Settings"
    public static let laterButton = "Later"

    public static let readyTitle = "TransPaste is ready"
    public static let readyText = "Accessibility granted — select text anywhere and press Ctrl+Cmd+T."

    // MARK: Setup assistant

    public static let setupAllSetTitle = "All set"
    public static func setupAllSetText(providerName: String) -> String {
        """
        Accessibility permission ✓
        Provider: \(providerName) ✓

        Select text anywhere and press Ctrl+Cmd+T.
        """
    }
    public static func setupOneStepLeft(providerName: String) -> String {
        "Accessibility is on — one step left: \(providerName) needs an API key. Or pick a key-less provider (Ollama) from the Provider menu."
    }

    // MARK: API keys

    public static func apiKeySavedTitle(_ providerName: String) -> String {
        "\(providerName) API Key Saved"
    }
    public static func apiKeySavedText(maskedKey: String) -> String {
        "Key: \(maskedKey)\n\nSelect text anywhere and press Ctrl+Cmd+T."
    }
    public static let clipboardEmptyTitle = "Clipboard Empty or Invalid"
    public static let clipboardEmptyText = "Copy your API key to the clipboard first, then use this menu item again."

    public static func missingKeyTitle(_ providerName: String) -> String {
        "\(providerName) needs an API key"
    }
    public static let missingKeyText = "Copy your key, then click \"Paste from Clipboard\" — or open the key page first."
    public static let pasteFromClipboardButton = "Paste from Clipboard"
    public static let openKeyPageButton = "Open Key Page"

    // MARK: Custom provider

    public static let customProviderTitle = "Custom Provider"
    public static let customProviderText = """
        Any OpenAI-compatible Chat Completions endpoint works: Ollama, LM Studio, vLLM, OpenRouter, LiteLLM...
        Set a token via "Paste API Key from Clipboard (optional)" if the endpoint needs one; local servers usually don't.
        """
    public static let customProviderHint = "Endpoint URL (top) and model name (bottom)"
    public static let saveButton = "Save"

    // MARK: Translation flow

    public static let translatePromptTitle = "Translate this text?"
    public static let translateButton = "Translate"
    public static let cancelButton = "Cancel"
    public static let resultTitle = "Translation Result"
    public static let pasteButton = "Paste"
    public static let okButton = "OK"

    public static func translationFailedTitle(_ providerName: String) -> String {
        "\(providerName) Translation Failed"
    }
    public static func localServerHint(endpoint: String) -> String {
        "\n\nIs the server at \(endpoint) running?"
    }

    // MARK: About

    public static func aboutTitle() -> String {
        "\(AppInfo.name) \(AppInfo.version)"
    }
    public static func aboutText(providerName: String, model: String, year: Int) -> String {
        """
        Instant in-place translation for macOS: select text anywhere, press Ctrl+Cmd+T, and the translation lands right back where you're working.

        Provider: \(providerName) (\(model))
        Config: ~/.transpaste/providers.json
        Log: ~/translator.log

        © \(year) \(AppInfo.author)
        """
    }
    public static let githubButton = "GitHub"
}
