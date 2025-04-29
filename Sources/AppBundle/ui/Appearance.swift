import SwiftUI

enum AppearanceType {
    case light
    case dark
}

@MainActor
public class Appearance: ObservableObject {
    public static let shared = Appearance()

    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] app, _ in
            Task { @MainActor in
                let name = app.effectiveAppearance.name
                let isDarkAppearance = name == .vibrantDark || name == .darkAqua || name == .accessibilityHighContrastDarkAqua || name == .accessibilityHighContrastVibrantDark
                self?.appAppearance = isDarkAppearance ? .dark : .light
            }
        }
    }

    /// System Settings -> Appearance -> Light/Dark
    /// This is the theme representing how the UI should look inside the app (this might be different than the menu bar color)
    @Published var appAppearance: AppearanceType = .dark
}
