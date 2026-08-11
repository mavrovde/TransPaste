import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, InputMonitorDelegate {
    var statusItem: NSStatusItem!
    var sourceLanguageMenu: NSMenu!
    var targetLanguageMenu: NSMenu!
    var providerMenu: NSMenu!
    var providerMenuItem: NSMenuItem!
    
    var currentSourceLanguage: String {
        get { UserDefaults.standard.string(forKey: "SourceLanguageV3") ?? "Russian" }
        set { UserDefaults.standard.set(newValue, forKey: "SourceLanguageV3") }
    }
    
    var currentTargetLanguage: String {
        get { UserDefaults.standard.string(forKey: "TargetLanguageV3") ?? "German" }
        set { UserDefaults.standard.set(newValue, forKey: "TargetLanguageV3") }
    }
    
    var isTranslationEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "IsTranslationEnabledV2") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "IsTranslationEnabledV2") }
    }
    
    let languages = ["Auto", "English", "Spanish", "French", "German", "Chinese", "Japanese", "Russian"]
    
    let inputMonitor = InputMonitor()
    let translationService = TranslationService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Create UI immediately so app is visible
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bubble.left.and.exclamationmark.bubble.right", accessibilityDescription: "TransPaste")
            button.appearsDisabled = !isTranslationEnabled
        }
        setupMenu()
        
        // 2. Then check permissions
        checkAndRequestPermissions()
    }

    func checkAndRequestPermissions() {
        // 1. Start the monitor (Registers Hotkey)
        inputMonitor.delegate = self
        inputMonitor.isEnabled = isTranslationEnabled // Sync state on launch
        _ = inputMonitor.start()
        
        // 2. Check Accessibility Permissions (Required for Cmd+C/Cmd+V macro)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            Logger.shared.log("Accessibility not enabled. Prompting user...")
            
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Permission Required"
                alert.informativeText = "TransPaste needs Accessibility permissions to Copy & Paste text.\n\n1. Open System Settings > Privacy & Security > Accessibility.\n2. Enable 'TransPaste'.\n3. Relaunch the app."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Quit")
                
                NSApp.activate(ignoringOtherApps: true)
                alert.layout()
                alert.window.level = .floating
                
                let response = alert.runModal()
                
                if response == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                } else {
                    NSApp.terminate(nil)
                }
            }
        } else {
            Logger.shared.log("Accessibility permissions confirmed.")
        }
    }
    
    // InputMonitorDelegate
    func triggerTranslation(for text: String, completion: @escaping (String?) -> Void) {
        Logger.shared.log("triggerTranslation called")
        
        // Only translate if meaningful content
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completion(nil)
            return
        }
        
        // 1. Show Input Dialog
        DispatchQueue.main.async {
            let response = self.showDialog(
                title: "Translate this text?",
                message: text,
                buttons: ["Translate", "Cancel"]
            )
            
            if response != .alertFirstButtonReturn {
                Logger.shared.log("User cancelled at input.")
                NSApp.hide(nil) // Hide if cancelled to restore focus
                completion(nil)
                return
            }
            
            // 2. Call the selected provider
            self.translationService.translate(text: text, from: self.currentSourceLanguage, to: self.currentTargetLanguage) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let translation):
                        Logger.shared.log("Translation success: \(translation)")
                        
                        // 3. Show Output Dialog
                        let outResponse = self.showDialog(
                            title: "Translation Result",
                            message: translation,
                            buttons: ["Paste", "Cancel"]
                        )
                        
                        if outResponse == .alertFirstButtonReturn {
                             NSSound(named: "Glass")?.play()
                            
                             // 4. Hide App to restore focus to the original app
                             NSApp.hide(nil)
                             
                             // 5. Short delay to allow focus switch, then paste
                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                 completion(translation)
                             }
                        } else {
                            Logger.shared.log("User cancelled at output.")
                            NSApp.hide(nil)
                            completion(nil)
                        }
                        
                    case .failure(let error):
                        Logger.shared.log("Translation failed: \(error)")
                        NSSound(named: "Basso")?.play()
                        _ = self.showDialog(title: "Error", message: error.localizedDescription, buttons: ["OK"])
                        NSApp.hide(nil)
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // Helper for showing dialogs
    func showDialog(title: String, message: String, buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        // Determine style based on content length or type? Standard is fine.
        alert.alertStyle = .informational
        
        for btn in buttons {
            alert.addButton(withTitle: btn)
        }
        
        // Ensure TransPaste is active to show the alert
        NSApp.activate(ignoringOtherApps: true)
        alert.layout()
        alert.window.level = .floating
        
        return alert.runModal()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        Logger.shared.log("Setting up menu...")
        
        // Source Language Submenu
        let sourceItem = NSMenuItem(title: "Source: \(currentSourceLanguage)", action: nil, keyEquivalent: "")
        sourceLanguageMenu = NSMenu()
        for lang in languages {
            let item = NSMenuItem(title: lang, action: #selector(selectSourceLanguage(_:)), keyEquivalent: "")
            item.target = self
            if lang == currentSourceLanguage { item.state = .on }
            sourceLanguageMenu.addItem(item)
        }
        menu.setSubmenu(sourceLanguageMenu, for: sourceItem)
        menu.addItem(sourceItem)
        
        // Target Language Submenu
        let targetItem = NSMenuItem(title: "Target: \(currentTargetLanguage)", action: nil, keyEquivalent: "")
        targetLanguageMenu = NSMenu()
        for lang in languages {
            let item = NSMenuItem(title: lang, action: #selector(selectTargetLanguage(_:)), keyEquivalent: "")
            item.target = self
            if lang == currentTargetLanguage { item.state = .on }
            targetLanguageMenu.addItem(item)
        }
        menu.setSubmenu(targetLanguageMenu, for: targetItem)
        menu.addItem(targetItem)

        // Provider Submenu — everything provider-related lives here:
        // picker with readiness state, key actions for the selected provider,
        // custom endpoint config, and the providers.json escape hatch.
        providerMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        providerMenu = NSMenu()
        providerMenu.delegate = self  // refresh readiness on every open
        menu.setSubmenu(providerMenu, for: providerMenuItem)
        menu.addItem(providerMenuItem)
        rebuildProviderMenu()
        menu.delegate = self  // refresh the ⚠ readiness title before display

        menu.addItem(NSMenuItem.separator())

        // Toggle Translation
        let toggleItem = NSMenuItem(title: "Enable Translation (Ctrl+Cmd+T)", action: #selector(toggleTranslation(_:)), keyEquivalent: "t")
        toggleItem.keyEquivalentModifierMask = [.command, .control]
        toggleItem.state = isTranslationEnabled ? .on : .off
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())
        
        // Debug
        menu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(checkPermissions(_:)), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())

        // About + Quit
        let aboutItem = NSMenuItem(title: "About \(AppInfo.name)", action: #selector(showAbout(_:)), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func checkPermissions(_ sender: NSMenuItem) {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        let alert = NSAlert()
        if accessEnabled {
            alert.messageText = "Permissions Granted"
            alert.informativeText = "Access confirmed! Starting Input Monitor..."
            
            // Actually start the monitor now that we have permissions
            Logger.shared.log("Manual permission check passed. Starting monitor.")
            inputMonitor.delegate = self
            _ = inputMonitor.start()
            
        } else {
            alert.messageText = "Permissions Denied"
            alert.informativeText = "Permission is still missing.\n1. Open System Settings > Privacy > Input Monitoring.\n2. Toggle TransPaste ON (or remove and re-add)."
            alert.addButton(withTitle: "Open Settings")
        }
        
        NSApp.activate(ignoringOtherApps: true)
        alert.layout()
        alert.window.level = .floating
        let result = alert.runModal()
        
        if !accessEnabled && result == .alertFirstButtonReturn {
             if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc func toggleTranslation(_ sender: NSMenuItem) {
        isTranslationEnabled.toggle()
        inputMonitor.isEnabled = isTranslationEnabled
        sender.state = isTranslationEnabled ? .on : .off
        
        if let button = statusItem.button {
            button.appearsDisabled = !isTranslationEnabled
        }
    }
    
    /// Rebuilds the provider submenu: providers with inline readiness,
    /// then contextual actions for the currently selected provider only.
    func rebuildProviderMenu() {
        let current = TranslationService.currentProvider
        providerMenu.removeAllItems()

        for provider in TranslationProvider.allCases {
            let title = provider.isReady
                ? provider.displayName
                : "\(provider.displayName) — needs API key"
            let item = NSMenuItem(title: title, action: #selector(selectProvider(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = provider.rawValue
            if provider == current { item.state = .on }
            providerMenu.addItem(item)
        }

        providerMenu.addItem(NSMenuItem.separator())

        // Contextual actions for the selected provider. Every provider can
        // take a key (key-less ones send it as an optional Bearer token, e.g.
        // remote/authed Ollama), so the paste item is always offered.
        let pasteTitle = current.requiresAPIKey
            ? "Paste API Key from Clipboard"
            : "Paste API Key from Clipboard (optional)"
        let paste = NSMenuItem(title: pasteTitle, action: #selector(pasteAPIKey(_:)), keyEquivalent: "")
        paste.target = self
        providerMenu.addItem(paste)

        if !current.apiKeyURL.isEmpty {
            // Ollama's URL is its download page, not an API key page
            let getTitle = current.requiresAPIKey
                ? "Get \(current.displayName) API Key..."
                : "Open \(current.displayName) Website..."
            let get = NSMenuItem(title: getTitle, action: #selector(openAPIKeyURL(_:)), keyEquivalent: "")
            get.target = self
            providerMenu.addItem(get)
        }
        if current == .custom {
            let configure = NSMenuItem(title: "Configure Endpoint & Model...", action: #selector(configureCustomProvider(_:)), keyEquivalent: "")
            configure.target = self
            providerMenu.addItem(configure)
        }
        let edit = NSMenuItem(title: "Edit providers.json...", action: #selector(editProvidersConfig(_:)), keyEquivalent: "")
        edit.target = self
        providerMenu.addItem(edit)

        providerMenuItem.title = current.isReady
            ? "Provider: \(current.displayName)"
            : "Provider: \(current.displayName) ⚠"
    }

    // Keep readiness marks fresh every time the root menu or the provider
    // submenu opens (keys can change via env vars or the config file)
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === providerMenu || menu === statusItem.menu {
            rebuildProviderMenu()
        }
    }

    @objc func selectProvider(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let provider = TranslationProvider(rawValue: rawValue) else { return }
        TranslationService.currentProvider = provider
        rebuildProviderMenu()
        Logger.shared.log("Provider switched to \(provider.displayName)")

        // Guided setup: picking an unready provider offers the key right away
        // instead of failing at first translation
        if !provider.isReady {
            promptForMissingKey(provider)
        }
    }

    func promptForMissingKey(_ provider: TranslationProvider) {
        let alert = NSAlert()
        alert.messageText = "\(provider.displayName) needs an API key"
        alert.informativeText = "Copy your key, then click \"Paste from Clipboard\" — or open the key page first."
        alert.addButton(withTitle: "Paste from Clipboard")
        alert.addButton(withTitle: "Open Key Page")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        alert.layout()
        alert.window.level = .floating

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            saveAPIKeyFromClipboard(for: provider)
        case .alertSecondButtonReturn:
            if let url = URL(string: provider.apiKeyURL) {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
        rebuildProviderMenu()
    }

    @objc func editProvidersConfig(_ sender: NSMenuItem) {
        _ = ProviderConfig.endpoint(for: .gemini)  // ensures the file exists
        NSWorkspace.shared.open(ProviderConfig.configURL)
    }

    @objc func pasteAPIKey(_ sender: NSMenuItem) {
        saveAPIKeyFromClipboard(for: TranslationService.currentProvider)
        rebuildProviderMenu()
    }

    func saveAPIKeyFromClipboard(for provider: TranslationProvider) {
        if let key = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            UserDefaults.standard.set(key, forKey: provider.defaultsKey)

            // Show confirmation
            let alert = NSAlert()
            alert.messageText = "\(provider.displayName) API Key Saved"
            alert.informativeText = "Key: \(key.prefix(5))...\(key.suffix(3))"
            alert.alertStyle = .informational
            // Ensure visibility
            NSApp.activate(ignoringOtherApps: true)
            alert.layout()
            alert.window.level = .floating
            alert.runModal()
        } else {
            let alert = NSAlert()
            alert.messageText = "Clipboard Empty or Invalid"
            alert.informativeText = "Please copy your API Key first."
            alert.alertStyle = .warning
            NSApp.activate(ignoringOtherApps: true)
            alert.layout()
            alert.window.level = .floating
            alert.runModal()
        }
    }
    
    @objc func openAPIKeyURL(_ sender: NSMenuItem) {
        if let url = URL(string: TranslationService.currentProvider.apiKeyURL) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showAbout(_ sender: NSMenuItem) {
        let provider = TranslationService.currentProvider
        let alert = NSAlert()
        alert.messageText = "\(AppInfo.name) \(AppInfo.version)"
        alert.informativeText = """
        On-the-fly translation for macOS — press Ctrl+Cmd+T in any app.

        Provider: \(provider.displayName) (\(provider.model))
        Config: ~/.transpaste/providers.json
        Log: ~/translator.log

        © \(Calendar.current.component(.year, from: Date())) \(AppInfo.author)
        """
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub")

        NSApp.activate(ignoringOtherApps: true)
        alert.layout()
        alert.window.level = .floating

        if alert.runModal() == .alertSecondButtonReturn,
           let url = URL(string: AppInfo.repoURL) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func configureCustomProvider(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Custom Provider"
        alert.informativeText = "Any OpenAI-compatible Chat Completions endpoint works: Ollama, LM Studio, vLLM, OpenRouter, LiteLLM...\nSet a token via \"Paste API Key from Clipboard (optional)\" if the endpoint needs one; local servers usually don't."

        let endpointField = NSTextField(frame: NSRect(x: 0, y: 58, width: 360, height: 24))
        endpointField.placeholderString = "Endpoint URL"
        endpointField.stringValue = TranslationProvider.customEndpoint

        let modelField = NSTextField(frame: NSRect(x: 0, y: 26, width: 360, height: 24))
        modelField.placeholderString = "Model name (e.g. llama3.2)"
        modelField.stringValue = TranslationProvider.customModel

        let hint = NSTextField(labelWithString: "Endpoint URL (top) and model name (bottom)")
        hint.frame = NSRect(x: 0, y: 0, width: 360, height: 18)
        hint.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 86))
        container.addSubview(endpointField)
        container.addSubview(modelField)
        container.addSubview(hint)
        alert.accessoryView = container

        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        alert.layout()
        alert.window.level = .floating
        alert.window.initialFirstResponder = endpointField

        if alert.runModal() == .alertFirstButtonReturn {
            let endpoint = endpointField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !endpoint.isEmpty { TranslationProvider.customEndpoint = endpoint }
            if !model.isEmpty { TranslationProvider.customModel = model }
            Logger.shared.log("Custom provider configured: \(model) @ \(endpoint)")
        }
    }
    
    @objc func selectSourceLanguage(_ sender: NSMenuItem) {
        currentSourceLanguage = sender.title
        updateMenuState(menu: sourceLanguageMenu, selectedTitle: currentSourceLanguage)
        // Update the main menu item title to reflect selection
        statusItem.menu?.item(at: 0)?.title = "Source: \(currentSourceLanguage)"
    }
    
    @objc func selectTargetLanguage(_ sender: NSMenuItem) {
        currentTargetLanguage = sender.title
        updateMenuState(menu: targetLanguageMenu, selectedTitle: currentTargetLanguage)
        statusItem.menu?.item(at: 1)?.title = "Target: \(currentTargetLanguage)"
    }
    
    func updateMenuState(menu: NSMenu, selectedTitle: String) {
        for item in menu.items {
            item.state = (item.title == selectedTitle) ? .on : .off
        }
    }
}
