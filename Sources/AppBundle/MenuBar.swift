import Common
import Foundation
import SwiftUI

public func menuBar(viewModel: TrayMenuModel) -> some Scene {
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
        AerospaceIcon(viewModel.isEnabled ? viewModel.trayText : "⏸️")
    }
}

struct MonospacedText: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        let renderer = ImageRenderer(
            content: Text(text)
                .font(.system(.largeTitle, design: .monospaced))
                .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
        )
        if let cgImage = renderer.cgImage {
            // Using scale: 1 results in a blurry image for unknown reasons
            Image(cgImage, scale: 2, label: Text(text))
        } else {
            // In case image can't be rendered fallback to plain text
            Text(text)
        }
    }
}

struct AerospaceIcon: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var text: String
    
    let cornerRadius = 8.0
    let elementSpacing = 4.0
    let maxDisplayedMonitors = 4
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        let elements = text.split(separator: " │ ")
        let renderer = ImageRenderer(
            content: HStack (alignment: .bottom, spacing: elementSpacing) {
                ForEach(0...maxDisplayedMonitors, id: \.self) {
                    if ($0 < elements.count) {
                        if (elements[$0].starts(with: "*")) {
                            let index = elements[$0].index(elements[$0].startIndex, offsetBy: 1)
                            let text = elements[$0][index...]
                            let t = Text(text)
                                .font(.system(.largeTitle, design: .monospaced))
                                .bold()
                                .foregroundStyle(.black)
                                .padding(4)
                            let r = t.background(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
                            )
                            r.mask {
                                ZStack {
                                    RoundedRectangle(cornerRadius: cornerRadius)
                                        .fill(.white)
                                    t
                                }
                                .compositingGroup()
                                .luminanceToAlpha()
                            }
                        } else {
                            Text(elements[$0])
                                .font(.system(.largeTitle, design: .monospaced))
                                .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: cornerRadius).stroke(colorScheme == .light ? Color.black : Color.white, lineWidth: 2))
                        }
                    }
                }
            }
        )
        if let cgImage = renderer.cgImage {
            // Using scale: 1 results in a blurry image for unknown reasons
            Image(cgImage, scale: 2, label: Text(text))
        } else {
            // In case image can't be rendered fallback to plain text
            Text(text)
        }
    }
}

func getTextEditorToOpenConfig() -> URL {
    NSWorkspace.shared.urlForApplication(toOpen: findCustomConfigUrl().urlOrNil ?? defaultConfigUrl)?
        .takeIf { $0.lastPathComponent != "Xcode.app" } // Blacklist Xcode. It is too heavy to open plain text files
        ?? URL(filePath: "/System/Applications/TextEdit.app")
}
