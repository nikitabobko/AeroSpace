enum KnownBundleId: String, Equatable {

    case activityMonitor = "com.apple.ActivityMonitor"
    case alacritty = "org.alacritty"
    case emacs = "org.gnu.Emacs"
    case finder = "com.apple.finder"
    case ghostty = "com.mitchellh.ghostty"
    case gimp = "org.gimp.gimp-2.10"
    case iphonesimulator = "com.apple.iphonesimulator"
    case iterm2 = "com.googlecode.iterm2"
    case kitty = "net.kovidgoyal.kitty"
    case photoBooth = "com.apple.PhotoBooth"
    case qutebrowser = "org.qutebrowser.qutebrowser"
    case steam = "com.valvesoftware.steam.helper"
    case wezterm = "com.github.wez.wezterm"
    case zoom = "us.zoom.xos"

    case mozillaFirefox = "org.mozilla.firefox"
    case mozillaFirefoxDeveloperEdition = "org.mozilla.firefoxdeveloperedition"
    case mozillaFirefoxNightly = "org.mozilla.nightly"

    case vscode = "com.microsoft.VSCode"
    case vscodium = "com.vscodium"

    var isFirefox: Bool {
        self == .mozillaFirefox || self == .mozillaFirefoxDeveloperEdition || self == .mozillaFirefoxNightly
    }

    var isVscode: Bool {
        self == .vscode || self == .vscodium
    }
}
