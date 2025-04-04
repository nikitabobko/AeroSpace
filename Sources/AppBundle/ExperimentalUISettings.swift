import AppKit
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
    var filterEmptyWorkspacesFromMenu: Bool {
        get {
            return UserDefaults.standard.bool(forKey: ExperimentalUISettingsItems.filterEmptyWorkspacesFromMenu.rawValue)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: ExperimentalUISettingsItems.filterEmptyWorkspacesFromMenu.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
}

enum ExperimentalUISettingsItems: String {
    case displayStyle
    case filterEmptyWorkspacesFromMenu
}

@MainActor
func getExperimentalUISettingsMenu(viewModel: TrayMenuModel) -> some View {
    Menu {
        Text("Menu bar display style:")
        ForEach(MenuBarStyle.allCases) { item in
            Button {
                viewModel.experimentalUISettings.displayStyle = item
            } label: {
                Toggle(isOn: .constant(viewModel.experimentalUISettings.displayStyle == item)) {
                    Text(item.title)
                }
            }
        }.id(viewModel.experimentalUISettings.displayStyle)
        Divider()
        Text("Menu content:")
        Button {
            viewModel.experimentalUISettings.filterEmptyWorkspacesFromMenu.toggle()
        } label: {
            Toggle(isOn: .constant(viewModel.experimentalUISettings.filterEmptyWorkspacesFromMenu)) {
                Text("Filter empty workspaces")
            }.id(viewModel.experimentalUISettings.filterEmptyWorkspacesFromMenu)
        }
    } label: {
        Text("Experimental UI Settings")
    }
}
