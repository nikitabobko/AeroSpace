import AppKit

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

// Covered by tests in ./axDumps in the repo root
extension AxUiElementMock {
    // 'isDialogHeuristic' function name is referenced in the guide
    func isDialogHeuristic(
        _ id: KnownBundleId?,
        _ windowLevel: MacOsWindowLevel?,
    ) -> Bool {
        // Note: a lot of windows don't have title on startup. So please don't rely on the title

        if id == ._1password && windowLevel != .normalWindow {
            return true
        }

        if id == .iphonesimulator {
            return true
        }

        // Don't tile:
        // - Chrome cmd+f window ("AXUnknown" value)
        // - login screen (Yes fuck, it's also a window from Apple's API perspective) ("AXUnknown" value)
        // - XCode "Build succeeded" popup
        // - IntelliJ tooltips, context menus, drop downs
        // - macOS native file picker (IntelliJ -> "Open...") (kAXDialogSubrole value)
        //
        // Minimized windows or windows of a hidden app have subrole "AXDialog"
        if getIndividual(Ax.subroleAttr) != kAXStandardWindowSubrole &&
            id != .qutebrowser // qutebrowser regular window has AXDialog subrole when decorations are disabled
        {
            return true
        }
        // Firefox: Picture in Picture window doesn't have minimize button.
        // todo. bug: when firefox shows non-native fullscreen, minimize button is disabled for all other non-fullscreen windows
        if id?.isFirefox == true && getIndividual(Ax.minimizeButtonAttr)?.getIndividual(Ax.enabledAttr) != true {
            return true
        }
        if id == .photoBooth { return true }
        if id == .ghostty {
            return getIndividual(Ax.fullscreenButtonAttr)?.getIndividual(Ax.enabledAttr) != true &&
                getIndividual(Ax.closeButtonAttr)?.getIndividual(Ax.enabledAttr) == true
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
        if getIndividual(Ax.fullscreenButtonAttr)?.getIndividual(Ax.enabledAttr) != true &&
            id != .gimp && // Gimp doesn't show fullscreen button

            // "Drag out" a tab out of Chrome window. Technically, it shouldn't be necessary, but
            // apparently there is some sort of race condition between users releasing mouse up and
            // Chrome reactivating the fullscreen button
            // todo: consider checking for fullscreen cirteria periodically (downside: will affect performance)
            id != .chrome &&

            id != .activityMonitor && // Activity Monitor doesn't show fullscreen button

            // Terminal apps and Emacs have an option to hide their title bars
            id != .alacritty && // ~/.alacritty.toml: window.decorations = "Buttonless"
            id != .kitty && // ~/.config/kitty/kitty.conf: hide_window_decorations titlebar-and-corners
            id != .wezterm &&
            id != .qutebrowser && // :set window.hide_decoration
            id != .iterm2 &&
            id != .emacs &&
            id?.isVscode != true && // "window.nativeFullScreen": false
            id != .steam
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
        _ id: KnownBundleId?,
        _ activationPolicy: NSApplication.ActivationPolicy,
        _ windowLevel: MacOsWindowLevel?,
    ) -> Bool {
        if windowLevel != .normalWindow &&
            // todo: Slowly roll out windowLevel for applications for which we have the appropriate dumps
            (id == .slack || id == .chrome || id?.isFirefox == true || id == .braveBrowser || id == .screenstudio || id == .cleanshotx || id == .iterm2 || id == .outlook || id == .codex || id == .wisprFlow || id == .finder)
        {
            return false
        }

        // FL Studio draws its own title bars. Its windows don't have AX title bar buttons, and their subrole is AXUnknown,
        // so the heuristics below treat all of them as popups. https://github.com/nikitabobko/AeroSpace/discussions/1234
        // - Main window, "Welcome to FL Studio" window: normal level (the welcome window is modal panel level while FL Studio is active)
        // - Mixer, settings: floating level
        // - "Save changes?" dialog: modal panel level
        // - FL Studio's own menus (File menu, right click menus): pop up menu level. These are the only popups
        if id == .flStudio {
            return windowLevel == .normalWindow ||
                windowLevel == .alwaysOnTopWindow ||
                windowLevel == .unknown(windowLevel: Int(CGWindowLevelForKey(.modalPanelWindow)))
        }

        // Just don't do anything with "Ghostty Quick Terminal" windows.
        // Its position and size are managed by the Ghostty itself
        // https://github.com/nikitabobko/AeroSpace/issues/103
        // https://github.com/ghostty-org/ghostty/discussions/3512
        if id == .ghostty && getIndividual(Ax.identifierAttr) == "com.mitchellh.ghostty.quickTerminal" {
            return false
        }

        lazy var fullscreenButton = getIndividual(Ax.fullscreenButtonAttr)

        if id == .xcode && getIndividual(Ax.identifierAttr) == "open_quickly" {
            return false
        }

        if id == .iterm2 && fullscreenButton == nil {
            return false
        }

        if activationPolicy == .accessory && getIndividual(Ax.closeButtonAttr) == nil && id != .steam {
            return false
        }

        // Emacs child frames (posframes, corfu completion popups, etc.)
        // These are transient UI elements that should not be managed as windows.
        // https://github.com/nikitabobko/AeroSpace/issues/776
        if id == .emacs && getIndividual(Ax.subroleAttr) == kAXFloatingWindowSubrole {
            return false
        }

        if id?.isFirefox != true {
            return isWindowHeuristicOld(axApp: axApp)
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
        return getIndividual(Ax.closeButtonAttr) != nil ||
            fullscreenButton != nil ||
            getIndividual(Ax.zoomButtonAttr) != nil ||
            getIndividual(Ax.minimizeButtonAttr) != nil ||

            getIndividual(Ax.isFocused) == true ||  // 3 different ways to detect if the window is focused
            getIndividual(Ax.isMainAttr) == true ||
            axApp.getIndividual(Ax.focusedWindowAttr)?.windowId == self.containingNativeWindowId() ||

            getIndividual(Ax.subroleAttr) == kAXStandardWindowSubrole
    }

    private func isWindowHeuristicOld(axApp: AxUiElementMock) -> Bool { // 0.18.3 hotfix
        lazy var subrole = getIndividual(Ax.subroleAttr)
        lazy var title = getIndividual(Ax.titleAttr) ?? ""

        // Try to filter out incredibly weird popup like AXWindows without any buttons.
        // E.g.
        // - Sonoma (macOS 14) keyboard layout switch
        // - IntelliJ context menu (right mouse click)
        // - Telegram context menu (right mouse click)
        if getIndividual(Ax.closeButtonAttr) == nil &&
            getIndividual(Ax.fullscreenButtonAttr) == nil &&
            getIndividual(Ax.zoomButtonAttr) == nil &&
            getIndividual(Ax.minimizeButtonAttr) == nil &&

            getIndividual(Ax.isFocused) == false &&  // Three different ways to detect if the window is not focused
            getIndividual(Ax.isMainAttr) == false &&
            axApp.getIndividual(Ax.focusedWindowAttr)?.windowId != containingNativeWindowId() &&

            subrole != kAXStandardWindowSubrole &&
            // Share window purple "pill" indicator has "Window" title https://github.com/nikitabobko/AeroSpace/issues/1101
            (title.isEmpty || title == "Window") // Maybe it doesn't work in non-English locale
        {
            return false
        }
        return subrole == kAXStandardWindowSubrole ||
            subrole == kAXDialogSubrole || // macOS native file picker ("Open..." menu) (kAXDialogSubrole value)
            subrole == kAXFloatingWindowSubrole // telegram image viewer
    }

    func getWindowType(
        axApp: AxUiElementMock,
        _ id: KnownBundleId?,
        _ activationPolicy: NSApplication.ActivationPolicy,
        _ windowLevel: MacOsWindowLevel?,
    ) -> AxUiElementWindowType {
        .new(
            isWindow: isWindowHeuristic(axApp: axApp, id, activationPolicy, windowLevel),
            isDialog: { isDialogHeuristic(id, windowLevel) },
        )
    }
}
