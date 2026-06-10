import AppKit

@MainActor
enum ScreenResolver {

    static let displayIDKey = "selectedDisplayID"
    static let displayNameKey = "selectedDisplayName"

    // MARK: - Resolve

    /// Returns the user's chosen screen, or the primary screen as fallback.
    static func resolveTargetScreen() -> NSScreen? {
        let storedID = UInt32(UserDefaults.standard.integer(forKey: displayIDKey))
        guard storedID != 0 else {
            return NSScreen.screens.first
        }
        if let match = NSScreen.screens.first(where: { screenID($0) == storedID }) {
            return match
        }
        return NSScreen.screens.first
    }

    // MARK: - Identification

    /// Extract CGDirectDisplayID from an NSScreen.
    static func screenID(_ screen: NSScreen) -> Int {
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
        return Int(id)
    }

    /// Human-readable label for the settings picker.
    static func screenLabel(_ screen: NSScreen) -> String {
        let name = screen.localizedName
        if NSScreen.screens.first === screen {
            return "\(name) (Primary)"
        }
        return name
    }

    // MARK: - Save

    static func savePreference(screen: NSScreen) {
        UserDefaults.standard.set(screenID(screen), forKey: displayIDKey)
        UserDefaults.standard.set(screen.localizedName, forKey: displayNameKey)
    }

    static func savePrimaryPreference() {
        UserDefaults.standard.set(0, forKey: displayIDKey)
        UserDefaults.standard.removeObject(forKey: displayNameKey)
    }
}
