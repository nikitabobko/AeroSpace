import Common
import Foundation
import SwiftUI

@MainActor
struct MenuBarLabel: View {
    @Environment(\.colorScheme) var menuColorScheme: ColorScheme
    @EnvironmentObject var viewModel: TrayMenuModel
    let color: Color?
    let style: MenuBarStyle?

    let hStackSpacing = CGFloat(6)
    let itemSize = CGFloat(40)
    let itemBorderSize = CGFloat(3)
    let itemPadding = CGFloat(8)
    let itemCornerRadius = CGFloat(6)

    private var finalColor: Color {
        return color ?? (menuColorScheme == .dark ? Color.white : Color.black)
    }

    init(style: MenuBarStyle? = nil, color: Color? = nil) {
        self.style = style
        self.color = color
    }

    var body: some View {
        if #available(macOS 14, *) { // https://github.com/nikitabobko/AeroSpace/issues/1122
            let renderer = ImageRenderer(content: menuBarContent)
            if let cgImage = renderer.cgImage {
                // Using scale: 1 results in a blurry image for unknown reasons
                Image(cgImage, scale: 2, label: Text(viewModel.trayText))
            } else {
                // In case image can't be rendered fallback to plain text
                Text(viewModel.trayText)
            }
        } else { // macOS 13 and lower
            Text(viewModel.trayText)
        }
    }

    var menuBarContent: some View {
        return HStack(spacing: hStackSpacing) {
            let style = style ?? viewModel.experimentalUISettings.displayStyle
            switch style {
                case .monospacedText: getText(for: .monospaced)
                case .systemText: getText(for: .default)
                case .squares: squares
                case .i3:
                    squares
                    let workspaces = viewModel.workspaces.filter { !$0.isEffectivelyEmpty && !$0.isVisible }
                    if !workspaces.isEmpty {
                        otherWorkspaces(with: workspaces)
                    }
                case .i3Ordered:
                    orderedWorkspacesView(showApps: false)
                case .i3OrderedWithAppIcons:
                    orderedWorkspacesView(showApps: true)
            }
        }
    }

    private func getText(for design: Font.Design) -> some View {
        Text(viewModel.trayText)
            .font(.system(.largeTitle, design: design))
            .foregroundStyle(finalColor)
    }

    private var squares: some View {
        ForEach(viewModel.trayItems, id: \.id) { item in
            itemView(for: item)
            if item.type == .mode {
                modeSeparator(with: .monospaced)
            }
        }
    }

    private func otherWorkspaces(with otherWorkspaces: [WorkspaceViewModel]) -> some View {
        Group {
            Text("|")
                .font(.system(.largeTitle))
                .foregroundStyle(finalColor)
                .bold()
                .padding(.bottom, 6)
            ForEach(otherWorkspaces, id: \.name) { item in
                itemView(for: TrayItem(type: .workspace, name: item.name, isActive: false, hasFullscreenWindows: item.hasFullscreenWindows))
            }
        }
        .opacity(0.6)
    }

    private func modeSeparator(with design: Font.Design) -> some View {
        Text(":")
            .font(.system(.largeTitle, design: design))
            .foregroundStyle(finalColor)
            .bold()
    }

    @ViewBuilder
    fileprivate func itemView(for item: TrayItem) -> some View {
        let view = itemSubView(for: item)
        if item.hasFullscreenWindows {
            let strokeStyle = StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter, miterLimit: 10, dash: [10, 5], dashPhase: 3)
            view
                .padding(4)
                .overlay {
                    RoundedRectangle(cornerRadius: itemCornerRadius, style: .continuous)
                        .strokeBorder(finalColor, style: strokeStyle)
                }
        } else {
            view
        }
    }

    @ViewBuilder
    fileprivate func itemSubView(for item: TrayItem) -> some View {
        // If workspace name contains emojis we use the plain emoji in text to avoid visibility issues scaling the emoji to fit the squares
        if item.name.containsEmoji() {
            Text(item.name)
                .font(.system(.largeTitle))
                .foregroundStyle(finalColor)
                .frame(height: itemSize)
        } else {
            if let imageName = item.systemImageName {
                Image(systemName: imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(finalColor)
                    .frame(width: itemSize, height: itemSize)
            } else {
                let text = Text(item.name)
                    .font(.system(.largeTitle))
                    .bold()
                    .padding(.horizontal, itemBorderSize * 2)
                    .frame(height: itemSize)
                if item.isActive {
                    ZStack {
                        text.background {
                            RoundedRectangle(cornerRadius: itemCornerRadius, style: .circular)
                        }
                        text.blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .foregroundStyle(finalColor)
                    .frame(height: itemSize)
                } else {
                    text.background {
                        RoundedRectangle(cornerRadius: itemCornerRadius, style: .continuous)
                            .strokeBorder(lineWidth: itemBorderSize)
                    }
                    .foregroundStyle(finalColor)
                    .frame(height: itemSize)
                }
            }
        }
    }

    private func orderedWorkspacesView(showApps: Bool) -> some View {
        let modeItem = viewModel.trayItems.first { $0.type == .mode }
        let orderedWorkspaces = viewModel.workspaces.filter { !$0.isEffectivelyEmpty || $0.isVisible }
        return Group {
            if let modeItem {
                itemView(for: modeItem)
                modeSeparator(with: .monospaced)
            }
            ForEach(orderedWorkspaces, id: \.name) { ws in
                let trayItem = TrayItem(
                    type: .workspace,
                    name: ws.name,
                    isActive: ws.isFocused,
                    hasFullscreenWindows: ws.hasFullscreenWindows,
                )
                itemView(for: trayItem)
                    .opacity(ws.isVisible ? 1 : 0.5)
                if showApps {
                    let limit = style != nil ? (ws.isFocused ? 1 : 0) : ws.apps.count
                    ForEach(ws.apps.prefix(limit)) { app in
                        appIconView(for: app)
                            .opacity(ws.isFocused && app.isFocused ? 1 : 0.5)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func appIconView(for app: AppViewModel) -> some View {
        let icon = Image(nsImage: app.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: itemSize, height: itemSize)
        if app.isFocused {
            icon.clipShape(RoundedRectangle(cornerRadius: itemCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: itemCornerRadius, style: .continuous)
                        .strokeBorder(finalColor, lineWidth: 1)
                }
        } else {
            icon
        }
    }
}

extension String {
    fileprivate func containsEmoji() -> Bool {
        unicodeScalars.contains { $0.properties.isEmoji && $0.properties.isEmojiPresentation }
    }
}
