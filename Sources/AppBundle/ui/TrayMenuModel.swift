import AppKit
import Common

public final class TrayMenuModel: ObservableObject {
    @MainActor public static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
    @Published var trayItems: [TrayItem] = []
    /// Is "layouting" enabled
    @Published var isEnabled: Bool = true
    @Published var workspaces: [WorkspaceViewModel] = []
    @Published var experimentalUISettings: ExperimentalUISettings = ExperimentalUISettings()
    @Published var sponsorshipMessage: String = sponsorshipPrompts.randomElement().orDie()
}

@MainActor func updateTrayText() {
    let sortedMonitors = sortedMonitors
    let focus = focus
    TrayMenuModel.shared.trayText = (activeMode?.takeIf { $0 != mainModeId }?.first.map { "[\($0.uppercased())] " } ?? "") +
        sortedMonitors
        .map {
            let hasFullscreenWindows = $0.activeWorkspace.allLeafWindowsRecursive.contains { $0.isFullscreen }
            let activeWorkspaceName = hasFullscreenWindows ? "(\($0.activeWorkspace.name))" : $0.activeWorkspace.name
            return ($0.activeWorkspace == focus.workspace && sortedMonitors.count > 1 ? "*" : "") + activeWorkspaceName
        }
        .joined(separator: " │ ")
    TrayMenuModel.shared.workspaces = Workspace.all.map {
        let apps = $0.allLeafWindowsRecursive.map { $0.app.name?.takeIf { !$0.isEmpty } }.filterNotNil().toSet()
        let dash = " - "
        let suffix = switch true {
            case !apps.isEmpty: dash + apps.sorted().joinTruncating(separator: ", ", length: 25)
            case $0.isVisible: dash + $0.workspaceMonitor.name
            default: ""
        }
        let hasFullscreenWindows = $0.allLeafWindowsRecursive.contains { $0.isFullscreen }
        let appViewModels: [AppViewModel]
        if TrayMenuModel.shared.experimentalUISettings.displayStyle == .i3OrderedWithAppIcons {
            let focusedWindowId = focus.windowOrNil?.windowId
            appViewModels = $0.allLeafWindowsRecursive.map { window in
                AppViewModel(
                    windowId: window.windowId,
                    name: window.app.name ?? "Unknown",
                    icon: resolveAppIcon(for: window),
                    isFocused: window.windowId == focusedWindowId,
                )
            }
        } else {
            appViewModels = []
        }
        return WorkspaceViewModel(
            name: $0.name,
            suffix: suffix,
            isFocused: focus.workspace == $0,
            isEffectivelyEmpty: $0.isEffectivelyEmpty,
            isVisible: $0.isVisible,
            hasFullscreenWindows: hasFullscreenWindows,
            apps: appViewModels,
        )
    }
    var items = sortedMonitors.map {
        let hasFullscreenWindows = $0.activeWorkspace.allLeafWindowsRecursive.contains { $0.isFullscreen }
        return TrayItem(
            type: .workspace,
            name: $0.activeWorkspace.name,
            isActive: $0.activeWorkspace == focus.workspace,
            hasFullscreenWindows: hasFullscreenWindows,
        )
    }
    let mode = activeMode?.takeIf { $0 != mainModeId }?.first.map {
        TrayItem(type: .mode, name: $0.uppercased(), isActive: true, hasFullscreenWindows: false)
    }
    if let mode {
        items.insert(mode, at: 0)
    }
    TrayMenuModel.shared.trayItems = items
}

struct WorkspaceViewModel: Hashable {
    let name: String
    let suffix: String
    let isFocused: Bool
    let isEffectivelyEmpty: Bool
    let isVisible: Bool
    let hasFullscreenWindows: Bool
    let apps: [AppViewModel]

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

struct AppViewModel: Identifiable, Equatable {
    let windowId: UInt32
    let name: String
    let icon: NSImage
    let isFocused: Bool
    var id: UInt32 { windowId }

    static func == (lhs: AppViewModel, rhs: AppViewModel) -> Bool {
        lhs.windowId == rhs.windowId && lhs.isFocused == rhs.isFocused
    }
}

enum TrayItemType: String, Hashable {
    case mode
    case workspace
}

private let validLetters = "A" ... "Z"

struct TrayItem: Hashable, Identifiable {
    let type: TrayItemType
    let name: String
    let isActive: Bool
    let hasFullscreenWindows: Bool
    var systemImageName: String? {
        // System image type is only valid for numbers 0 to 50 and single capital char workspace name
        if let number = Int(name) {
            guard number >= 0 && number <= 50 else { return nil }
        } else if name.count == 1 {
            guard validLetters.contains(name) else { return nil }
        } else {
            return nil
        }
        let lowercasedName = name.lowercased()
        switch type {
            case .mode:
                return "\(lowercasedName).circle"
            case .workspace:
                if isActive {
                    return "\(lowercasedName).square.fill"
                } else {
                    return "\(lowercasedName).square"
                }
        }
    }
    var id: String {
        return type.rawValue + name
    }
}

@MainActor
private func resolveAppIcon(for window: Window) -> NSImage {
    if let macApp = window.app as? MacApp {
        if let icon = macApp.nsApp.icon {
            return icon
        }
        if let bundlePath = macApp.bundlePath {
            return NSWorkspace.shared.icon(forFile: bundlePath)
        }
        if let bundleId = macApp.rawAppBundleId,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
    }
    return NSImage(named: NSImage.applicationIconName) ?? NSImage()
}
