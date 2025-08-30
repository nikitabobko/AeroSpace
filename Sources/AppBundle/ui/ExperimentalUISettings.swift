import SwiftUI

struct ExperimentalUISettings {
    var displayStyle: MenuBarStyle {
        get {
            if let value = UserDefaults.standard.string(forKey: ExperimentalUISettingsItems.displayStyle.rawValue) {
                return MenuBarStyle(rawValue: value) ?? .monospacedText
            } else {
                return .monospacedText
            }
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: ExperimentalUISettingsItems.displayStyle.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    var centeredBarEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: ExperimentalUISettingsItems.centeredBarEnabled.rawValue)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: ExperimentalUISettingsItems.centeredBarEnabled.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    var centeredBarShowNumbers: Bool {
        get {
            if UserDefaults.standard.object(forKey: ExperimentalUISettingsItems.centeredBarShowNumbers.rawValue) == nil {
                return true // Default to true
            }
            return UserDefaults.standard.bool(forKey: ExperimentalUISettingsItems.centeredBarShowNumbers.rawValue)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: ExperimentalUISettingsItems.centeredBarShowNumbers.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    // Centered bar window level (affects z-order over menu bar)
    var centeredBarWindowLevel: CenteredBarWindowLevel {
        get {
            if let raw = UserDefaults.standard.string(forKey: ExperimentalUISettingsItems.centeredBarWindowLevel.rawValue),
               let value = CenteredBarWindowLevel(rawValue: raw) {
                return value
            }
            return .popup // default: above menu bar
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: ExperimentalUISettingsItems.centeredBarWindowLevel.rawValue)
            UserDefaults.standard.synchronize()
        }
    }

    // Target display for the centered bar
    var centeredBarTargetDisplay: CenteredBarTargetDisplay {
        get {
            if let raw = UserDefaults.standard.string(forKey: ExperimentalUISettingsItems.centeredBarTargetDisplay.rawValue),
               let value = CenteredBarTargetDisplay(rawValue: raw) {
                return value
            }
            return .focusedWorkspaceMonitor // default: follows focused workspace
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: ExperimentalUISettingsItems.centeredBarTargetDisplay.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable, Equatable, Hashable {
    case monospacedText
    case systemText
    case squares
    case i3
    var id: String { rawValue }
    var title: String {
        switch self {
            case .monospacedText: "Monospaced font"
            case .systemText: "System font"
            case .squares: "Square images"
            case .i3: "i3 style"
        }
    }
}

enum ExperimentalUISettingsItems: String {
    case displayStyle
    case centeredBarEnabled
    case centeredBarShowNumbers
    case centeredBarWindowLevel
    case centeredBarTargetDisplay
}

enum CenteredBarWindowLevel: String, CaseIterable, Identifiable, Equatable, Hashable {
    case status   // NSWindow.Level.statusBar
    case popup    // NSWindow.Level.popUpMenu (above menu bar)
    case screensaver // NSWindow.Level.screenSaver (highest common level)
    var id: String { rawValue }
    var title: String {
        switch self {
            case .status: "Status Bar"
            case .popup: "Popup (above menu bar)"
            case .screensaver: "Screen Saver (highest)"
        }
    }
}

enum CenteredBarTargetDisplay: String, CaseIterable, Identifiable, Equatable, Hashable {
    case focusedWorkspaceMonitor // monitor of the focused workspace
    case primary                 // main monitor (origin 0,0)
    case mouse                   // display under mouse cursor
    var id: String { rawValue }
    var title: String {
        switch self {
            case .focusedWorkspaceMonitor: "Focused Workspace Monitor"
            case .primary: "Primary Display"
            case .mouse: "Display Under Mouse"
        }
    }
}

@MainActor
func getExperimentalUISettingsMenu(viewModel: TrayMenuModel) -> some View {
    let color = AppearanceTheme.current == .dark ? Color.white : Color.black
    return Menu {
        Text("Menu bar style (macOS 14 or later):")
        Button {
            viewModel.experimentalUISettings.displayStyle = .monospacedText
        } label: {
            Toggle(isOn: .constant(viewModel.experimentalUISettings.displayStyle == .monospacedText)) {
                MenuBarLabel(viewModel.trayText, color: color)
                Text(" -  " + MenuBarStyle.monospacedText.title)
            }
        }
        Button {
            viewModel.experimentalUISettings.displayStyle = .systemText
        } label: {
            Toggle(isOn: .constant(viewModel.experimentalUISettings.displayStyle == .systemText)) {
                MenuBarLabel(viewModel.trayText, textStyle: .system, color: color)
                Text(" -  " + MenuBarStyle.systemText.title)
            }
        }
        Button {
            viewModel.experimentalUISettings.displayStyle = .squares
        } label: {
            Toggle(isOn: .constant(viewModel.experimentalUISettings.displayStyle == .squares)) {
                MenuBarLabel(viewModel.trayText, color: color, trayItems: viewModel.trayItems)
                Text(" -  " + MenuBarStyle.squares.title)
            }
        }
        Button {
            viewModel.experimentalUISettings.displayStyle = .i3
        } label: {
            Toggle(isOn: .constant(viewModel.experimentalUISettings.displayStyle == .i3)) {
                MenuBarLabel(viewModel.trayText, color: color, trayItems: viewModel.trayItems, workspaces: viewModel.workspaces)
                Text(" -  " + MenuBarStyle.i3.title)
            }
        }
        Divider()
        Text("Centered Workspace Bar:")
        Button {
            viewModel.experimentalUISettings.centeredBarEnabled.toggle()
            StatusBarManager.shared.toggleCenteredBar(viewModel: viewModel)
        } label: {
            Toggle(isOn: .constant(viewModel.experimentalUISettings.centeredBarEnabled)) {
                Text("Enable centered workspace bar with app icons")
            }
        }
        Button {
            viewModel.experimentalUISettings.centeredBarShowNumbers.toggle()
            if viewModel.experimentalUISettings.centeredBarEnabled {
                StatusBarManager.shared.updateCenteredBar(viewModel: viewModel)
            }
        } label: {
            Toggle(isOn: .constant(viewModel.experimentalUISettings.centeredBarShowNumbers)) {
                Text("Show workspace numbers")
            }
        }.disabled(!viewModel.experimentalUISettings.centeredBarEnabled)

        // Window level selection
        Text("Window Level:")
        ForEach(CenteredBarWindowLevel.allCases) { level in
            Button {
                viewModel.experimentalUISettings.centeredBarWindowLevel = level
                if viewModel.experimentalUISettings.centeredBarEnabled {
                    StatusBarManager.shared.updateCenteredBar(viewModel: viewModel)
                }
            } label: {
                Toggle(isOn: .constant(viewModel.experimentalUISettings.centeredBarWindowLevel == level)) {
                    Text(level.title)
                }
            }
        }
        .disabled(!viewModel.experimentalUISettings.centeredBarEnabled)

        // Target display selection
        Text("Target Display:")
        ForEach(CenteredBarTargetDisplay.allCases) { target in
            Button {
                viewModel.experimentalUISettings.centeredBarTargetDisplay = target
                if viewModel.experimentalUISettings.centeredBarEnabled {
                    StatusBarManager.shared.updateCenteredBar(viewModel: viewModel)
                }
            } label: {
                Toggle(isOn: .constant(viewModel.experimentalUISettings.centeredBarTargetDisplay == target)) {
                    Text(target.title)
                }
            }
        }
        .disabled(!viewModel.experimentalUISettings.centeredBarEnabled)
    } label: {
        Text("Experimental UI Settings (No stability guarantees)")
    }
}
