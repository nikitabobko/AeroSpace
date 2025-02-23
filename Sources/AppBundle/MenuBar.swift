import Common
import Foundation
import SwiftUI

public func menuBar(viewModel: TrayMenuModel) -> some Scene { // todo should it be converted to "SwiftUI struct"?
    MenuBarExtra {
        let shortIdentification = "\(aeroSpaceAppName) v\(aeroSpaceAppVersion) \(gitShortHash)"
        let identification      = "\(aeroSpaceAppName) v\(aeroSpaceAppVersion) \(gitHash)"
        Text(shortIdentification)
        Button("Copy to clipboard") { identification.copyToClipboard() }
            .keyboardShortcut("C", modifiers: .command)
        Divider()
        if viewModel.isEnabled {
            Text("Workspaces:")
            ForEach(viewModel.workspaces, id: \.name) { workspace in
                Button {
                    refreshSession(.menuBarButton, screenIsDefinitelyUnlocked: true) { _ = Workspace.get(byName: workspace.name).focusWorkspace() }
                } label: {
                    Toggle(isOn: .constant(workspace.isFocused)) {
                        Text(workspace.name + workspace.suffix).font(.system(.body, design: .monospaced))
                    }
                }
            }
            Divider()
        }
        Button(viewModel.isEnabled ? "Disable" : "Enable") {
            refreshSession(.menuBarButton, screenIsDefinitelyUnlocked: true) {
                _ = EnableCommand(args: EnableCmdArgs(rawArgs: [], targetState: .toggle)).run(.defaultEnv, .emptyStdin)
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
        }.keyboardShortcut("O", modifiers: .command)
        if viewModel.isEnabled {
            Button("Reload config") {
                refreshSession(.menuBarButton, screenIsDefinitelyUnlocked: true) { _ = reloadConfig() }
            }.keyboardShortcut("R", modifiers: .command)
        }
        Button("Quit \(aeroSpaceAppName)") {
            terminationHandler.beforeTermination()
            terminateApp()
        }.keyboardShortcut("Q", modifiers: .command)
    } label: {
        if viewModel.isEnabled {
            switch config.menuBarStyle {
                case .text:
                    MenuBarLabel(viewModel.trayText)
                case .squares:
                    MenuBarLabel(viewModel.trayText, trayItems: viewModel.trayItems)
                case .i3:
                    MenuBarLabel(viewModel.trayText, trayItems: viewModel.trayItems, workspaces: viewModel.workspaces)
            }
        } else {
            MenuBarLabel("⏸️")
        }
    }
}

struct MenuBarLabel: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var text: String
    var trayItems: [TrayItem]?
    var workspaces: [WorkspaceViewModel]?

    init(_ text: String, trayItems: [TrayItem]? = nil, workspaces: [WorkspaceViewModel]? = nil) {
        self.text = text
        self.trayItems = trayItems
        self.workspaces = workspaces
    }

    var body: some View {
        if #available(macOS 14, *) { // https://github.com/nikitabobko/AeroSpace/issues/1122
            let renderer = ImageRenderer(content: menuBarContent)
            if let cgImage = renderer.cgImage {
                // Using scale: 1 results in a blurry image for unknown reasons
                Image(cgImage, scale: 2, label: Text(text))
            } else {
                // In case image can't be rendered fallback to plain text
                Text(text)
            }
        } else {
            Text(text)
        }
    }

    @ViewBuilder
    var menuBarContent: some View {
        let color = colorScheme == .light ? Color.black : Color.white
        if let trayItems {
            HStack(spacing: 4) {
                ForEach(trayItems, id: \.name) { item in
                    if item.name.containsEmoji() {
                        Text(item.name)
                            .font(.system(.largeTitle, design: .monospaced))
                            .foregroundStyle(color)
                            .bold()
                    } else {
                        Image(systemName: item.systemImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(color)
                        if item.type == .mode {
                            Text(":")
                                .font(.system(.largeTitle, design: .monospaced))
                                .foregroundStyle(color)
                                .bold()
                        }
                    }
                }
                if workspaces != nil {
                    let otherWorkspaces = Workspace.all.filter { workspace in
                        !workspace.isEffectivelyEmpty && !trayItems.contains(where: { item in item.name == workspace.name })
                    }
                    if !otherWorkspaces.isEmpty {
                        Group {
                            Text("|")
                                .font(.system(.largeTitle, design: .monospaced))
                                .foregroundStyle(color)
                                .bold()
                                .padding(.bottom, 2)
                            ForEach(otherWorkspaces, id: \.name) { item in
                                if item.name.containsEmoji() {
                                    Text(item.name)
                                        .font(.system(.largeTitle, design: .monospaced))
                                        .foregroundStyle(color)
                                        .bold()
                                } else {
                                    Image(systemName: "\(item.name.lowercased()).square")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundStyle(color)
                                }
                            }
                        }
                        .opacity(0.6)
                    }
                }
            }
            .frame(height: 40)
        } else {
            Text(text)
                .font(.system(.largeTitle, design: .monospaced))
                .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
        }
    }
}

enum MenuBarStyle: String {
    case text = "text"
    case squares = "squares"
    case i3 = "i3"
}

extension String {
    func parseMenuBarStyle() -> MenuBarStyle? {
        if let parsed = MenuBarStyle(rawValue: self) {
            return parsed
        } else {
            return nil
        }
    }

    func containsEmoji() -> Bool {
        unicodeScalars.contains { $0.properties.isEmoji && $0.properties.isEmojiPresentation }
    }
}

func getTextEditorToOpenConfig() -> URL {
    NSWorkspace.shared.urlForApplication(toOpen: findCustomConfigUrl().urlOrNil ?? defaultConfigUrl)?
        .takeIf { $0.lastPathComponent != "Xcode.app" } // Blacklist Xcode. It is too heavy to open plain text files
        ?? URL(filePath: "/System/Applications/TextEdit.app")
}
