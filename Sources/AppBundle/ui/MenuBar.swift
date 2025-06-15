import Common
import Foundation
import SwiftUI

@MainActor
public func menuBar(viewModel: TrayMenuModel) -> some Scene { // todo should it be converted to "SwiftUI struct"?
    MenuBarExtra {
        let shortIdentification = "\(aeroSpaceAppName) v\(aeroSpaceAppVersion) \(gitShortHash)"
        let identification      = "\(aeroSpaceAppName) v\(aeroSpaceAppVersion) \(gitHash)"
        Text(shortIdentification)
        Button("Copy to clipboard") { identification.copyToClipboard() }
            .keyboardShortcut("C", modifiers: .command)
        Divider()
        if let token: RunSessionGuard = .isServerEnabled {
            Text("Workspaces:")
            ForEach(viewModel.workspaces, id: \.name) { workspace in
                Button {
                    Task {
                        try await runSession(.menuBarButton, token) { _ = Workspace.get(byName: workspace.name).focusWorkspace() }
                    }
                } label: {
                    Toggle(isOn: .constant(workspace.isFocused)) {
                        Text(workspace.name + workspace.suffix).font(.system(.body, design: .monospaced))
                    }
                }
            }
            Divider()
        }
        getExperimentalUISettingsMenu(viewModel: viewModel)
        Divider()
        Button(viewModel.isEnabled ? "Disable" : "Enable") {
            Task {
                try await runSession(.menuBarButton, .forceRun) { () throws in
                    _ = try await EnableCommand(args: EnableCmdArgs(rawArgs: [], targetState: .toggle))
                        .run(.defaultEnv, .emptyStdin)
                }
            }
        }.keyboardShortcut("E", modifiers: .command)
        let editor = getTextEditorToOpenConfig()
        Button("Open config in '\(editor.lastPathComponent)'") {
            let fallbackConfig: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: configDotfileName)
            switch findCustomConfigUrl() {
                case .file(let url):
                    url.open(with: editor)
                case .noCustomConfigExists:
                    _ = try? FileManager.default.copyItem(atPath: defaultConfigUrl.path, toPath: fallbackConfig.path)
                    fallbackConfig.open(with: editor)
                case .ambiguousConfigError:
                    fallbackConfig.open(with: editor)
            }
        }.keyboardShortcut(",", modifiers: .command)
        if let token: RunSessionGuard = .isServerEnabled {
            Button("Reload config") {
                Task {
                    try await runSession(.menuBarButton, token) { _ = reloadConfig() }
                }
            }.keyboardShortcut("R", modifiers: .command)
        }
        Button("Quit \(aeroSpaceAppName)") {
            Task {
                defer { terminateApp() }
                try await terminationHandler.beforeTermination()
            }
        }.keyboardShortcut("Q", modifiers: .command)
    } label: {
        if viewModel.isEnabled {
            switch viewModel.experimentalUISettings.displayStyle {
                case .monospacedText:
                    MenuBarLabel(viewModel.trayText)
                case .systemText:
                    MenuBarLabel(viewModel.trayText, textStyle: .system)
                case .squares:
                    MenuBarLabel(viewModel.trayText, trayItems: viewModel.trayItems)
                case .i3:
                    MenuBarLabel(viewModel.trayText, trayItems: viewModel.trayItems, workspaces: viewModel.workspaces)
            }
        } else {
            Image(systemName: "pause.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

func getTextEditorToOpenConfig() -> URL {
    NSWorkspace.shared.urlForApplication(toOpen: findCustomConfigUrl().urlOrNil ?? defaultConfigUrl)?
        .takeIf { $0.lastPathComponent != "Xcode.app" } // Blacklist Xcode. It is too heavy to open plain text files
        ?? URL(filePath: "/System/Applications/TextEdit.app")
}
