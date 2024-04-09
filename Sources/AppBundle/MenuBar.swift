import Common
import SwiftUI
import Foundation

public func menuBar(viewModel: TrayMenuModel) -> some Scene {
    MenuBarExtra {
        let shortIdentification = "\(Bundle.appName) v\(Bundle.appVersion) \(gitShortHash)"
        let identification      = "\(Bundle.appName) v\(Bundle.appVersion) \(gitHash)"
        Text(shortIdentification)
        Button("Copy to clipboard") { identification.copyToClipboard() }
            .keyboardShortcut("C", modifiers: .command)
        Divider()
        if viewModel.isEnabled {
            Text("Workspaces:")
            ForEach(Workspace.all) { (workspace: Workspace) in
                Button {
                    refreshSession { _ = WorkspaceCommand.run(.focused, workspace.name) }
                } label: {
                    Toggle(isOn: workspace == Workspace.focused
                        ? Binding(get: { true }, set: { _, _ in })
                        : Binding(get: { false }, set: { _, _ in })) {
                        let monitor = workspace.isVisible || !workspace.isEffectivelyEmpty ? " - \(workspace.workspaceMonitor.name)" : ""
                        Text(workspace.name + monitor).font(.system(.body, design: .monospaced))
                    }
                }
            }
            Divider()
        }
        Button(viewModel.isEnabled ? "Disable" : "Enable") {
            refreshSession {
                _ = EnableCommand(args: EnableCmdArgs(targetState: .toggle)).run(.focused)
            }
        }
            .keyboardShortcut("E", modifiers: .command)
        Button("Open Config") {
               let fileManager = FileManager.default
               let homeDirectory = NSHomeDirectory()
               let destinationPath = homeDirectory.appending("/.aerospace.toml")
               
               // Check if the config file already exists
               if !fileManager.fileExists(atPath: destinationPath) {
                   // Construct the source path of the default config file within the app bundle
                   if let sourcePath = Bundle.main.path(forResource: "default-config", ofType: "toml") {
                       do {
                           // Copy the default config file to the user's home directory
                           try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
                           print("Default config copied to \(destinationPath).")
                       } catch {
                           print("Error copying default config: \(error.localizedDescription)")
                           // Handle the error, possibly with an alert to the user
                       }
                   }
               }
               
               // Open the config file with the default application
               NSWorkspace.shared.openFile(destinationPath)
           }
           .keyboardShortcut("O", modifiers: .command)
        if viewModel.isEnabled {
            Button("Reload config") {
                refreshSession { _ = ReloadConfigCommand().run(.focused) }
            }
                .keyboardShortcut("R", modifiers: .command)
        }
        Button("Quit \(Bundle.appName)") {
            terminationHandler.beforeTermination()
            terminateApp()
        }
            .keyboardShortcut("Q", modifiers: .command)
    } label: {
        // .font(.system(.body, design: .monospaced)) doesn't work unfortunately :(
        Text(viewModel.isEnabled ? viewModel.trayText : "⏸️")
    }
}
