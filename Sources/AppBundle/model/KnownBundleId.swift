enum KnownBundleId: String, Equatable {

    case _1password = "com.1password.1password"
    case activityMonitor = "com.apple.ActivityMonitor"
    case alacritty = "org.alacritty"
    case braveBrowser = "com.brave.Browser"
    case chrome = "com.google.Chrome"
    case cleanshotx = "pl.maketheweb.cleanshotx"
    case emacs = "org.gnu.Emacs"
    case finder = "com.apple.finder"
    case fork = "com.DanPristupov.Fork"
    case ghostty = "com.mitchellh.ghostty"
    case gimp = "org.gimp.gimp-2.10"
    case iphonesimulator = "com.apple.iphonesimulator"
    case iterm2 = "com.googlecode.iterm2"
    case kitty = "net.kovidgoyal.kitty"
    case photoBooth = "com.apple.PhotoBooth"
    case qutebrowser = "org.qutebrowser.qutebrowser"
    case screenstudio = "com.timpler.screenstudio"
    case slack = "com.tinyspeck.slackmacgap"
    case steam = "com.valvesoftware.steam.helper"
    case wezterm = "com.github.wez.wezterm"
    case xcode = "com.apple.dt.Xcode"
    case zenBrowser = "app.zen-browser.zen"
    case zoom = "us.zoom.xos"

    case mozillaFirefox = "org.mozilla.firefox"
    case mozillaFirefoxDeveloperEdition = "org.mozilla.firefoxdeveloperedition"
    case mozillaFirefoxNightly = "org.mozilla.nightly"

    case vscode = "com.microsoft.VSCode"
    case vscodium = "com.vscodium"

    var isFirefox: Bool {
        self == .mozillaFirefox
            || self == .mozillaFirefoxDeveloperEdition
            || self == .mozillaFirefoxNightly
            || self == .zenBrowser
    }

    var isVscode: Bool {
        self == .vscode || self == .vscodium
    }

    /// True for apps that expose each native macOS tab as a separate AXWindow whose
    /// AX object stays valid after the tab is hidden. AeroSpace must trust the app's
    /// `AXWindows` (rather than the per-element `containingWindowId()`) to know which
    /// tabs are actually visible right now.
    var hasTabsAsWindows: Bool {
        self == .fork || self == .ghostty
    }
}
