import AppKit

// Covered by tests in ./axDumps in the repor root
extension AxUiElementMock {
    // 'isDialogHeuristic' function name is referenced in the guide
    func isDialogHeuristic(appBundleId id: String?) -> Bool {
        // Note: a lot of windows don't have title on startup. So please don't rely on the title

        if id == "com.apple.iphonesimulator" {
            return true
        }

        lazy var isQutebrowser = id == "org.qutebrowser.qutebrowser"

        // Don't tile:
        // - Chrome cmd+f window ("AXUnknown" value)
        // - login screen (Yes fuck, it's also a window from Apple's API perspective) ("AXUnknown" value)
        // - XCode "Build succeeded" popup
        // - IntelliJ tooltips, context menus, drop downs
        // - macOS native file picker (IntelliJ -> "Open...") (kAXDialogSubrole value)
        //
        // Minimized windows or windows of a hidden app have subrole "AXDialog"
        if get(Ax.subroleAttr) != kAXStandardWindowSubrole &&
            !isQutebrowser // qutebrowser regular window has AXDialog subrole when decorations are disabled
        {
            return true
        }
        // Firefox: Picture in Picture window doesn't have minimize button.
        // todo. bug: when firefox shows non-native fullscreen, minimize button is disabled for all other non-fullscreen windows
        if id?.isFirefoxId() == true && get(Ax.minimizeButtonAttr)?.get(Ax.enabledAttr) != true {
            return true
        }
        if id == "com.apple.PhotoBooth" { return true }
        if id == "com.mitchellh.ghostty" {
            return get(Ax.fullscreenButtonAttr)?.get(Ax.enabledAttr) != true &&
                get(Ax.closeButtonAttr)?.get(Ax.enabledAttr) == true
        }
        // Heuristic: float windows without fullscreen button (such windows are not designed to be big)
        // - IntelliJ various dialogs (Rebase..., Edit commit message, Settings, Project structure)
        // - Finder copy file dialog
        // - System Settings
        // - Apple logo -> About this Mac
        // - Calculator
        // - Battle.net login dialog
        // Fullscreen button is presented but disabled:
        // - Safari -> Pinterest -> Log in with Google
        // - Kap screen recorder https://github.com/wulkano/Kap
        // - flameshot? https://github.com/nikitabobko/AeroSpace/issues/112
        // - Drata Agent https://github.com/nikitabobko/AeroSpace/issues/134
        if get(Ax.fullscreenButtonAttr)?.get(Ax.enabledAttr) != true &&
            id != "org.gimp.gimp-2.10" && // Gimp doesn't show fullscreen button
            id != "com.apple.ActivityMonitor" && // Activity Monitor doesn't show fullscreen button

            // Terminal apps and Emacs have an option to hide their title bars
            id != "org.alacritty" && // ~/.alacritty.toml: window.decorations = "Buttonless"
            id != "net.kovidgoyal.kitty" && // ~/.config/kitty/kitty.conf: hide_window_decorations titlebar-and-corners
            id != "com.github.wez.wezterm" &&
            !isQutebrowser && // :set window.hide_decoration
            id != "com.googlecode.iterm2" &&
            id != "org.gnu.Emacs" &&
            id != "com.microsoft.VSCode" && id != "com.vscodium" && // "window.nativeFullScreen": false
            id != "com.valvesoftware.steam.helper"
        {
            return true
        }
        return false
    }

    /// Alternative name: !isPopup
    ///
    /// Why do we need to filter out non-windows?
    /// - "floating by default" workflow
    /// - It's annoying that the focus command treats these popups as floating windows
    func isWindowHeuristic(
        axApp: AxUiElementMock,
        appBundleId: String?,
        _ activationPolicy: NSApplication.ActivationPolicy,
    ) -> Bool {
        // Just don't do anything with "Ghostty Quick Terminal" windows.
        // Its position and size are managed by the Ghostty itself
        // https://github.com/nikitabobko/AeroSpace/issues/103
        // https://github.com/ghostty-org/ghostty/discussions/3512
        if appBundleId == "com.mitchellh.ghostty" && get(Ax.identifierAttr) == "com.mitchellh.ghostty.quickTerminal" {
            return false
        }

        if activationPolicy == .accessory && get(Ax.closeButtonAttr) == nil && appBundleId != "com.valvesoftware.steam.helper" {
            return false
        }

        if appBundleId?.isFirefoxId() != true {
            return isWindowHeuristicOld(axApp: axApp, appBundleId: appBundleId)
        }

        // Try to filter out incredibly weird popup like AXWindows without any buttons.
        // E.g.
        // - Sonoma (macOS 14) keyboard layout switch (AXSubrole == AXDialog)
        // - IntelliJ context menu (right mouse click)
        // - Telegram context menu (right mouse click)
        // - Share window purple "pill" indicator https://github.com/nikitabobko/AeroSpace/issues/1101. Title is not empty
        // - Tooltips on links mouse hover in browsers (Chrome, Firefox)
        // - Tooltips on buttons (e.g. new tab, Extensions) mouse hover in browsers (Chrome, Firefox). Title is not empty
        // Make sure that the following AXWindow remain windows:
        // - macOS native file picker ("Open..." menu) (subrole == kAXDialogSubrole)
        // - telegram image viewer (subrole == kAXFloatingWindowSubrole)
        // - Finder preview (hit space) (subrole == "Quick Look")
        // - Firefox non-native video fullscreen (about:config -> full-screen-api.macos-native-full-screen -> false, subrole == AXUnknown)
        return get(Ax.closeButtonAttr) != nil ||
            get(Ax.fullscreenButtonAttr) != nil ||
            get(Ax.zoomButtonAttr) != nil ||
            get(Ax.minimizeButtonAttr) != nil ||

            get(Ax.isFocused) == true ||  // 3 different ways to detect if the window is focused
            get(Ax.isMainAttr) == true ||
            axApp.get(Ax.focusedWindowAttr)?.windowId == self.containingWindowId() ||

            get(Ax.subroleAttr) == kAXStandardWindowSubrole
    }

    private func isWindowHeuristicOld(axApp: AxUiElementMock, appBundleId: String?) -> Bool { // 0.18.3 hotfix
        lazy var subrole = get(Ax.subroleAttr)
        lazy var title = get(Ax.titleAttr) ?? ""

        // Try to filter out incredibly weird popup like AXWindows without any buttons.
        // E.g.
        // - Sonoma (macOS 14) keyboard layout switch
        // - IntelliJ context menu (right mouse click)
        // - Telegram context menu (right mouse click)
        if get(Ax.closeButtonAttr) == nil &&
            get(Ax.fullscreenButtonAttr) == nil &&
            get(Ax.zoomButtonAttr) == nil &&
            get(Ax.minimizeButtonAttr) == nil &&

            get(Ax.isFocused) == false &&  // Three different ways to detect if the window is not focused
            get(Ax.isMainAttr) == false &&
            axApp.get(Ax.focusedWindowAttr)?.windowId != containingWindowId() &&

            subrole != kAXStandardWindowSubrole &&
            // Share window purple "pill" indicator has "Window" title https://github.com/nikitabobko/AeroSpace/issues/1101
            (title.isEmpty || title == "Window") // Maybe it doesn't work in non-English locale
        {
            return false
        }
        return subrole == kAXStandardWindowSubrole ||
            subrole == kAXDialogSubrole || // macOS native file picker ("Open..." menu) (kAXDialogSubrole value)
            subrole == kAXFloatingWindowSubrole || // telegram image viewer
            appBundleId == "com.apple.finder" && subrole == "Quick Look" // Finder preview (hit space) is a floating window
    }

    func getWindowType(
        axApp: AxUiElementMock,
        appBundleId: String?,
        _ activationPolicy: NSApplication.ActivationPolicy,
    ) -> AxUiElementWindowType {
        .new(
            isWindow: isWindowHeuristic(axApp: axApp, appBundleId: appBundleId, activationPolicy),
            isDialog: { isDialogHeuristic(appBundleId: appBundleId) },
        )
    }
}

enum AxUiElementWindowType: String {
    case window
    case dialog
    /// Not even a real window
    case popup

    static func new(isWindow: Bool, isDialog: () -> Bool) -> AxUiElementWindowType {
        switch true {
            case !isWindow: .popup
            case isDialog(): .dialog
            default: .window
        }
    }
}

extension String {
    fileprivate func isFirefoxId() -> Bool {
        ["org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly"].contains(self)
    }
}
