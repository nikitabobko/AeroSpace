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
        MenuBarStyleButton(.monospacedText, viewModel, color) { MenuBarLabel(viewModel.trayText, color: color) }
        MenuBarStyleButton(.systemText, viewModel, color) { MenuBarLabel(viewModel.trayText, textStyle: .system, color: color) }
        MenuBarStyleButton(.squares, viewModel, color) { MenuBarLabel(viewModel.trayText, color: color, trayItems: viewModel.trayItems) }
        MenuBarStyleButton(.i3, viewModel, color) { MenuBarLabel(viewModel.trayText, color: color, trayItems: viewModel.trayItems, workspaces: viewModel.workspaces) }
        MenuBarStyleButton(.i3Ordered, viewModel, color) { MenuBarLabel(viewModel.trayText, color: color, trayItems: viewModel.trayItems, workspaces: viewModel.workspaces, ordered: true) }
    } label: {
        Text("Experimental UI Settings (No stability guarantees)")
    }
}

@MainActor
func MenuBarStyleButton(
    _ style: MenuBarStyle,
    _ viewModel: TrayMenuModel,
    _ color: Color,
    _ menuBarLabel: () -> some View,
) -> some View {
    Button {
        viewModel.experimentalUISettings.displayStyle = style
    } label: {
        Toggle(isOn: .constant(viewModel.experimentalUISettings.displayStyle == style)) {
            menuBarLabel()
            Text(" -  " + style.title)
        }
    }
}
