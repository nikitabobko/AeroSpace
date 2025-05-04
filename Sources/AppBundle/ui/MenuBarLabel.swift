import Common
import Foundation
import SwiftUI

@MainActor
struct MenuBarLabel: View {
    @Environment(\.colorScheme) var menuColorScheme: ColorScheme
    var text: String
    var textStyle: MenuBarTextStyle
    var color: Color?
    var trayItems: [TrayItem]?
    var workspaces: [WorkspaceViewModel]?

    let hStackSpacing = CGFloat(6)
    let itemSize = CGFloat(40)
    let itemBorderSize = CGFloat(4)
    let itemPadding = CGFloat(8)
    let itemCornerRadius = CGFloat(6)

    private var finalColor: Color {
        return color ?? (menuColorScheme == .dark ? Color.white : Color.black)
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
                    if let workspaces {
                        let otherWorkspaces = workspaces.filter { !$0.isEffectivelyEmpty && !$0.isVisible }
                        if !otherWorkspaces.isEmpty {
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
                    }
                }
                .frame(height: itemSize)
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

private extension String {
    func containsEmoji() -> Bool {
        unicodeScalars.contains { $0.properties.isEmoji && $0.properties.isEmojiPresentation }
    }
}
