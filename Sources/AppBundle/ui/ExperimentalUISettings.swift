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
}

enum MenuBarStyle: String, CaseIterable, Identifiable, Equatable, Hashable {
    case monospacedText
    case systemText
    case squares
    case i3
    case i3Ordered
    var id: String { rawValue }
    var title: String {
        switch self {
            case .monospacedText: "Monospaced font"
            case .systemText: "System font"
            case .squares: "Square images"
            case .i3: "i3 style grouped"
            case .i3Ordered: "i3 style ordered"
        }
    }
}

enum ExperimentalUISettingsItems: String {
    case displayStyle
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
        Button {
            viewModel.experimentalUISettings.displayStyle = .i3Ordered
        } label: {
            Toggle(isOn: .constant(viewModel.experimentalUISettings.displayStyle == .i3Ordered)) {
                MenuBarLabel(viewModel.trayText, color: color, workspaces: viewModel.workspaces)
                Text(" -  " + MenuBarStyle.i3Ordered.title)
            }
        }
    } label: {
        Text("Experimental UI Settings (No stability guarantees)")
    }
}
