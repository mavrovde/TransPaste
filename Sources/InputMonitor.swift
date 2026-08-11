import Cocoa
import CoreGraphics
import Carbon

public protocol InputMonitorDelegate: AnyObject {
    func triggerTranslation(for text: String, completion: @escaping (String?) -> Void)
}

public class InputMonitor {
    weak public var delegate: InputMonitorDelegate?
    public var isEnabled = true
    
    private var hotKeyID: EventHotKeyID?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    // Key Codes
    let kVK_ANSI_T = 0x11
    let kVK_ANSI_A = 0x00
    let kVK_ANSI_C = 0x08
    let kVK_ANSI_V = 0x09
    let kVK_Command = 0x37

    public init() {}

    public func start() -> Bool {
        // "Check Permissions" in the menu calls start() again — re-registering the
        // same hotkey would fire the handler twice per keypress
        guard hotKeyRef == nil else {
            Logger.shared.log("Hotkey already registered. Skipping re-registration.")
            return true
        }

        Logger.shared.log("Registering Carbon Hotkey (Ctrl+Cmd+T)...")

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // installEventHandler is a C function, handling it in Swift can be tricky with closures.
        // We use a global helper or a static closure if possible, or Unmanaged self.
        
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (handler, event, userData) -> OSStatus in
                let monitor = Unmanaged<InputMonitor>.fromOpaque(userData!).takeUnretainedValue()
                monitor.handleHotKey()
                return noErr
            },
            1,
            &eventType,
            ptr,
            &eventHandlerRef
        )
        
        if status != noErr {
            Logger.shared.log("Failed to install event handler: \(status)")
            return false
        }
        
        // Register Hotkey: Ctrl + Cmd + T
        let hotKeyID = EventHotKeyID(signature: OSType(0x1111), id: 1)
        self.hotKeyID = hotKeyID
        
        let modifiers = cmdKey + controlKey
        
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus != noErr {
            Logger.shared.log("Failed to register hotkey: \(registerStatus)")
            return false
        }
        
        Logger.shared.log("Carbon Hotkey Registered Successfully.")
        return true
    }

    deinit {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func handleHotKey() {
        guard isEnabled else { return }
        Logger.shared.log("Carbon Hotkey Detected! Triggering macro...")
        
        DispatchQueue.main.async {
            self.performTranslationMacro()
        }
    }
    
    private var isMacroRunning = false
    
    private func performTranslationMacro() {
         guard !isMacroRunning else {
             Logger.shared.log("Macro already running. Ignoring duplicate trigger.")
             return
         }
         
         isMacroRunning = true
         Logger.shared.log("Executing Macro: Select All -> Copy -> Translate -> Paste")
         
         // Ensure we are hidden so the target app has focus
         DispatchQueue.main.async {
             NSApplication.shared.hide(nil)
         }
         
         // 0. Try Accessibility API first (Cleanest method)
         if let axText = getSelectedText(), !axText.isEmpty {
             Logger.shared.log("Captured Text via AX: \(axText.prefix(20))...")
             handleCapturedText(axText)
             return
         }
         
         Logger.shared.log("AX failed (or empty), falling back to Clipboard Macro...")
         
         // 1. Select All (Cmd + A)
         postKeyEvent(keyCode: kVK_ANSI_A, command: true)
         
         // 2. Schedule Copy
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
             // 1.5 Clear Clipboard to avoid stale data
             NSPasteboard.general.clearContents()
             
             // 2. Copy (Cmd + C)
             self.postKeyEvent(keyCode: self.kVK_ANSI_C, command: true)
             
             // 3. Start checking clipboard after delay
             self.checkClipboard(retries: 20)
         }
    }
    
    private func getSelectedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let error = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if error == .success, let focusedElement = focusedElement {
            let element = focusedElement as! AXUIElement
            var selectedText: AnyObject?
            let textError = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
            
            if textError == .success, let text = selectedText as? String {
                return text
            } else {
                Logger.shared.log("AX Failed to get selected text: \(textError.rawValue)")
            }
        } else {
             Logger.shared.log("AX Failed to get focused element: \(error.rawValue)")
             
             // Check if it's a permission issue specifically
             if error.rawValue == -25211 { // kAXErrorAPIDisabled
                 Logger.shared.log("CRITICAL: Accessibility API Disabled (-25211). User needs to re-enable permissions.")
                 // Ideally we'd notify the delegate here to show an alert, but we don't want to block the fallback mechanism yet.
                 // We will let the clipboard fallback try effectively, but if that fails too, we know why.
             }
        }
        return nil
    }
    
    private func checkClipboard(retries: Int) {
        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            handleCapturedText(text)
        } else if retries > 0 {
            // Retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.checkClipboard(retries: retries - 1)
            }
        } else {
            // Failed
            Logger.shared.log("Clipboard empty or invalid after retries.")
            isMacroRunning = false // Reset lock
            
            // Notify failure via delegate (maybe?) or just log.
            // If both AX and Clipboard fail, it's likely permissions.
        }
    }
    
    private func handleCapturedText(_ text: String) {
        Logger.shared.log("Captured Text: \(text.prefix(20))...")

        guard let delegate = delegate else {
            Logger.shared.log("No delegate set. Dropping captured text.")
            isMacroRunning = false
            return
        }

        delegate.triggerTranslation(for: text) { translatedText in
            self.isMacroRunning = false // Reset lock when done (or cancelled)
            guard let translatedText = translatedText else { return }
            
            // The delegate handles the dialogs.
            // If it returns a string, it means the user confirmed PASTE.
            
            DispatchQueue.main.async {
                Logger.shared.log("Preparing to paste...")
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.declareTypes([.string], owner: nil)
                pasteboard.setString(translatedText, forType: .string)
                
                // Wait for clipboard then Paste
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    Logger.shared.log("Sending Cmd+V...")
                    self.postKeyEvent(keyCode: self.kVK_ANSI_V, command: true)
                    Logger.shared.log("Pasted translation.")
                }
            }
        }
    }
    
    // Internal for testing
    func postKeyEvent(keyCode: Int, command: Bool) {
        // Try combined session state to be safer, or nil
        let source = CGEventSource(stateID: .combinedSessionState)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
        if command { keyDown?.flags = .maskCommand }
        keyDown?.post(tap: .cghidEventTap)
        
        // No usleep here, allow natural propagation
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false)
        if command { keyUp?.flags = .maskCommand }
        keyUp?.post(tap: .cghidEventTap)
    }
}
