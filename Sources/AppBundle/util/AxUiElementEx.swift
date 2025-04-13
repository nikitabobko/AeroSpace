import AppKit

extension AXUIElement {
    // 'isDialogHeuristic' function name is referenced in the guide
    func isDialogHeuristic(_ app: NSRunningApplication) -> Bool {
        let id = app.bundleIdentifier
        // Note: a lot of windows don't have title on startup. So please don't rely on the title

        // Don't tile:
        // - Chrome cmd+f window ("AXUnknown" value)
        // - login screen (Yes fuck, it's also a window from Apple's API perspective) ("AXUnknown" value)
        // - XCode "Build succeeded" popup
        // - IntelliJ tooltips, context menus, drop downs
        // - macOS native file picker (IntelliJ -> "Open...") (kAXDialogSubrole value)
        //
        // Minimized windows or windows of a hidden app have subrole "AXDialog"
        if get(Ax.subroleAttr) != kAXStandardWindowSubrole {
            return true
        }
        // Firefox: Picture in Picture window doesn't have minimize button.
        // todo. bug: when firefox shows non-native fullscreen, minimize button is disabled for all other non-fullscreen windows
        if app.isFirefox() && get(Ax.minimizeButtonAttr)?.get(Ax.enabledAttr) != true {
            return true
        }
        if id == "com.apple.PhotoBooth" { return true }
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
        if !isFullscreenable(self) &&
            id != "org.gimp.gimp-2.10" && // Gimp doesn't show fullscreen button
            id != "com.apple.ActivityMonitor" && // Activity Monitor doesn't show fullscreen button

            // Terminal apps and Emacs have an option to hide their title bars
            id != "org.alacritty" && // ~/.alacritty.toml: window.decorations = "Buttonless"
            id != "net.kovidgoyal.kitty" && // ~/.config/kitty/kitty.conf: hide_window_decorations titlebar-and-corners
            id != "com.mitchellh.ghostty" && // ~/.config/ghostty/config: window-decoration = false
            id != "com.github.wez.wezterm" &&
            id != "com.googlecode.iterm2" &&
            id != "org.gnu.Emacs"
        {
            return true
        }
        return false
    }

    // todo create a database of problematic windows and cover the function with tests
    /// Alternative name: !isPopup
    ///
    /// Why do we need to filter out non-windows?
    /// - "floating by default" workflow
    /// - It's annoying that the focus command treats these popups as floating windows
    func isWindowHeuristic(axApp: AXUIElement, appBundleId: String?) -> Bool {
        // Just don't do anything with "Ghostty Quick Terminal" windows.
        // Its position and size are managed by the Ghostty itself
        // https://github.com/nikitabobko/AeroSpace/issues/103
        // https://github.com/ghostty-org/ghostty/discussions/3512
        if appBundleId == "com.mitchellh.ghostty" && get(Ax.identifierAttr) == "com.mitchellh.ghostty.quickTerminal" {
            return false
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
}

private func isFullscreenable(_ axWindow: AXUIElement) -> Bool {
    if let fullscreenButton = axWindow.get(Ax.fullscreenButtonAttr) {
        return fullscreenButton.get(Ax.enabledAttr) == true
    }
    return false
}
