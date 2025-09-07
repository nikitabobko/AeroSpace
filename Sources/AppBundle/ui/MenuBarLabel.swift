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
    let itemBorderSize = CGFloat(4)
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
                    let modeItem = viewModel.trayItems.first { $0.type == .mode }
                    if let modeItem {
                        itemView(for: modeItem)
                        modeSeparator(with: .monospaced)
                    }
                    let orderedWorkspaces = viewModel.workspaces.filter { !$0.isEffectivelyEmpty || $0.isVisible }
                    ForEach(orderedWorkspaces, id: \.name) { item in
                        itemView(for: TrayItem(type: .workspace, name: item.name, isActive: item.isFocused))
                            .opacity(item.isVisible ? 1 : 0.5)
                    }
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
                itemView(for: TrayItem(type: .workspace, name: item.name, isActive: false))
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
                        RoundedRectangle(cornerRadius: itemCornerRadius, style: .circular)
                            .strokeBorder(lineWidth: itemBorderSize)
                    }
                    .foregroundStyle(finalColor)
                    .frame(height: itemSize)
                }
            }
        }
    }
}

extension String {
    fileprivate func containsEmoji() -> Bool {
        unicodeScalars.contains { $0.properties.isEmoji && $0.properties.isEmojiPresentation }
    }
}
