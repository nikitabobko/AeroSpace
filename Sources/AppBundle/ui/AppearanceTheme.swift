import SwiftUI
import Common

enum AppearanceTheme {
    case light
    case dark

    /// System Settings -> Appearance -> Light/Dark
    /// This is the theme representing how the UI should look inside the app (this might be different than the menu bar color)
    @MainActor
    static var current: AppearanceTheme {
        let name = NSApplication.shared.effectiveAppearance.name
        let isDarkAppearance = name == .vibrantDark ||
            name == .darkAqua ||
            name == .accessibilityHighContrastDarkAqua ||
            name == .accessibilityHighContrastVibrantDark
        return isDarkAppearance ? .dark : .light
    }
}
