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
                case .systemText:
                    MenuBarLabel(viewModel.trayText, textStyle: .system)
                case .monospacedText:
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

@MainActor
struct MenuBarLabel: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var text: String
    var textStyle: MenuBarTextStyle
    var color: Color?
    var trayItems: [TrayItem]?
    var workspaces: [WorkspaceViewModel]?

    let hStackSpacing = CGFloat(4)
    let itemHeight = CGFloat(40)
    let itemBorderSize = CGFloat(4)
    let itemCornerRadius = CGFloat(6)

    var finalColor: Color {
        return color ?? (colorScheme == .dark ? Color.white : Color.black)
    }

    init(_ text: String, textStyle: MenuBarTextStyle = .monospaced, color: Color? = nil, trayItems: [TrayItem]? = nil, workspaces: [WorkspaceViewModel]? = nil) {
        self.text = text
        self.textStyle = textStyle
        self.color = color
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
        } else { // macOS 13 and lower
            Text(text)
        }
    }

    var menuBarContent: some View {
        return ZStack {
            if let trayItems {
                HStack(spacing: hStackSpacing) {
                    ForEach(trayItems, id: \.id) { item in
                        itemView(for: item)
                        if item.type == .mode {
                            Text(":")
                                .font(.system(.largeTitle, design: textStyle.design))
                                .foregroundStyle(finalColor)
                                .bold()
                        }
                    }
                    if workspaces != nil {
                        let otherWorkspaces = Workspace.all.filter { workspace in
                            !workspace.isEffectivelyEmpty && !trayItems.contains(where: { item in item.type == .monitor && item.name == workspace.name })
                        }
                        if !otherWorkspaces.isEmpty {
                            Group {
                                Text("|")
                                    .font(.system(.largeTitle, design: textStyle.design))
                                    .foregroundStyle(finalColor)
                                    .bold()
                                    .padding(.bottom, 2)
                                ForEach(otherWorkspaces, id: \.name) { item in
                                    itemView(for: TrayItem(type: .monitor, name: item.name, isActive: false))
                                }
                            }
                            .opacity(0.6)
                        }
                    }
                }
                .frame(height: itemHeight)
            } else {
                HStack(spacing: hStackSpacing) {
                    Text(text)
                        .font(.system(.largeTitle, design: textStyle.design))
                        .foregroundStyle(finalColor)
                }
            }
        }
    }

    @ViewBuilder
    fileprivate func itemView(for item: TrayItem) -> some View {
        if item.name.containsEmoji() {
            // If workspace name contains emojis we use the plain emoji in text to avoid visibility issues scaling the emoji to fit the squares
            Text(item.name)
                .font(.system(.largeTitle, design: textStyle.design))
                .foregroundStyle(finalColor)
        } else {
            if let imageName = item.systemImageName {
                Image(systemName: imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(finalColor)
            } else {
                let text = Text(item.name)
                    .font(.system(.largeTitle, design: textStyle.design))
                    .bold()
                    .padding(.horizontal, item.isActive ? itemBorderSize * 2 : itemBorderSize * 1.5)
                    .frame(height: itemHeight)
                if item.isActive {
                    ZStack {
                        text.foregroundStyle(.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: itemCornerRadius, style: .circular)
                            )
                        text.blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .foregroundStyle(finalColor)
                } else {
                    text
                        .padding(.horizontal, itemBorderSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: itemCornerRadius, style: .circular)
                                .strokeBorder(lineWidth: itemBorderSize)
                        )
                        .foregroundStyle(finalColor)
                }
            }
        }
    }
}

enum MenuBarTextStyle: String {
    case monospaced
    case system
    var design: Font.Design {
        switch self {
            case .monospaced:
                return .monospaced
            case .system:
                return .default
        }
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable, Equatable, Hashable {
    case monospacedText
    case systemText
    case squares
    case i3
    var id: Int {
        return self.hashValue
    }
    var title: String {
        switch self {
            case .monospacedText: "Monospaced font"
            case .systemText: "System font"
            case .squares: "Square images"
            case .i3: "i3 style"
        }
    }
}

private extension String {
    func containsEmoji() -> Bool {
        unicodeScalars.contains { $0.properties.isEmoji && $0.properties.isEmojiPresentation }
    }
}

func getTextEditorToOpenConfig() -> URL {
    NSWorkspace.shared.urlForApplication(toOpen: findCustomConfigUrl().urlOrNil ?? defaultConfigUrl)?
        .takeIf { $0.lastPathComponent != "Xcode.app" } // Blacklist Xcode. It is too heavy to open plain text files
        ?? URL(filePath: "/System/Applications/TextEdit.app")
}
