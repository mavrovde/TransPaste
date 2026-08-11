import Foundation

// Covers every user-facing message and warning: present, actionable, and
// correctly parameterized. AppDelegate shows nothing that isn't defined in
// UserMessages (or TranslationError.errorDescription, tested separately).
func runMessagesTests() {

    test("all static messages and buttons are non-empty and free of raw placeholders") {
        let all: [String: String] = [
            "permissionRequiredTitle": UserMessages.permissionRequiredTitle,
            "permissionRequiredText": UserMessages.permissionRequiredText,
            "openSettingsButton": UserMessages.openSettingsButton,
            "laterButton": UserMessages.laterButton,
            "readyTitle": UserMessages.readyTitle,
            "setupAllSetTitle": UserMessages.setupAllSetTitle,
            "readyText": UserMessages.readyText,
            "clipboardEmptyTitle": UserMessages.clipboardEmptyTitle,
            "clipboardEmptyText": UserMessages.clipboardEmptyText,
            "missingKeyText": UserMessages.missingKeyText,
            "pasteFromClipboardButton": UserMessages.pasteFromClipboardButton,
            "openKeyPageButton": UserMessages.openKeyPageButton,
            "customProviderTitle": UserMessages.customProviderTitle,
            "customProviderText": UserMessages.customProviderText,
            "customProviderHint": UserMessages.customProviderHint,
            "saveButton": UserMessages.saveButton,
            "translatePromptTitle": UserMessages.translatePromptTitle,
            "translateButton": UserMessages.translateButton,
            "cancelButton": UserMessages.cancelButton,
            "resultTitle": UserMessages.resultTitle,
            "pasteButton": UserMessages.pasteButton,
            "okButton": UserMessages.okButton,
            "githubButton": UserMessages.githubButton,
        ]
        for (name, message) in all {
            expect(!message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   "\(name) must not be empty")
            expect(!message.contains("\\("), "\(name) has an unrendered placeholder: \(message)")
        }
    }

    test("permission messages tell the user exactly what to do") {
        expect(UserMessages.permissionRequiredText.contains("Accessibility"))
        expect(UserMessages.permissionRequiredText.contains(UserMessages.openSettingsButton),
               "required-text must reference the button it asks the user to click")
        expect(UserMessages.permissionRequiredText.contains("No relaunch"),
               "must reflect the automatic grant detection")
        expect(!UserMessages.permissionRequiredText.contains("Relaunch the app"),
               "stale relaunch instruction must be gone")
        expect(UserMessages.readyText.contains("Ctrl+Cmd+T"), "ready message teaches the hotkey")
    }

    test("setup assistant messages chain the steps and teach the hotkey") {
        let allSet = UserMessages.setupAllSetText(providerName: "Google Gemini")
        expect(allSet.contains("Google Gemini"))
        expect(allSet.contains("Accessibility"))
        expect(allSet.contains("Ctrl+Cmd+T"), "final step must teach the hotkey")

        let oneStep = UserMessages.setupOneStepLeft(providerName: "OpenAI")
        expect(oneStep.contains("OpenAI"))
        expect(oneStep.contains("API key"), "must say what the remaining step is")
        expect(oneStep.contains("Ollama"), "must offer the key-less escape hatch")

        expect(UserMessages.apiKeySavedText(maskedKey: "sk-ab...xyz").contains("Ctrl+Cmd+T"),
               "saving the key completes setup — teach the hotkey right there")
    }

    test("parameterized messages interpolate their arguments") {
        expect(UserMessages.apiKeySavedTitle("OpenAI").contains("OpenAI"))
        expect(UserMessages.apiKeySavedText(maskedKey: "sk-ab...xyz").contains("sk-ab...xyz"))
        expect(UserMessages.missingKeyTitle("Anthropic Claude").contains("Anthropic Claude"))
        expect(UserMessages.translationFailedTitle("Google Gemini").contains("Google Gemini"))
        expect(UserMessages.localServerHint(endpoint: "http://localhost:11434/v1/chat/completions")
            .contains("http://localhost:11434"), "hint must name the actual endpoint")
    }

    test("missing-key prompt references its own buttons") {
        expect(UserMessages.missingKeyText.contains(UserMessages.pasteFromClipboardButton),
               "instructional text must match the button title it references")
    }

    test("custom provider dialog references a real menu item title") {
        // This literal must match the paste item title rebuildProviderMenu()
        // creates for key-less providers
        expect(UserMessages.customProviderText.contains("Paste API Key from Clipboard (optional)"))
        expect(UserMessages.customProviderText.contains("OpenAI-compatible"))
    }

    test("about dialog carries version, author, provider, and support paths") {
        let about = UserMessages.aboutText(providerName: "Ollama (local)", model: "llama3.2", year: 2026)
        expect(UserMessages.aboutTitle().contains(AppInfo.version))
        expect(about.contains(AppInfo.author))
        expect(about.contains("Ollama (local)"))
        expect(about.contains("llama3.2"))
        expect(about.contains("providers.json"))
        expect(about.contains("translator.log"))
        expect(about.contains("© 2026"))
        expect(!about.contains("on-the-fly") && !about.contains("On-the-fly"),
               "retired phrasing must not return")
    }
}
