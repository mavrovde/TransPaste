import Foundation

/// Single source of truth for app metadata. build.sh injects `version` into
/// the bundle's Info.plist (CFBundleShortVersionString/CFBundleVersion), so
/// bump it here only.
public enum AppInfo {
    public static let name = "TransPaste"
    public static let version = "1.1.0"
    public static let author = "Sergii Mavrov"
    public static let repoURL = "https://github.com/mavrovde/TransPaste"
}
