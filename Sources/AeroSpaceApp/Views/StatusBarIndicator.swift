import AppBundle
import Combine
import Common
import SwiftUI

struct StatusBarIndicator: View {
    @StateObject var viewModel: TrayMenuModel

    var workSpaceSingle: some View {
        HStack {
            if let font = NSFont(name: config.fontFamily, size: config.fontSize) {
                Text(Workspace.all.filter { $0.isVisible }.first?.name ?? "")
                    .shadow(radius: 3)
                    .font(Font(font))
            } else {
                Text(viewModel.trayText)
            }
        }
        .padding(.horizontal, 5)
        .frame(minWidth: 25)
    }

    var workSpaceFull: some View {
        HStack(spacing: 4) {
            ForEach(Workspace.all) { workspace in
                Text(workspace.name)
                    .shadow(radius: 3)
                    .font(
                        Font(
                            NSFont(name: config.fontFamily, size: config.fontSize)
                                ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                        )
                    )
                    .frame(minWidth: 20)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .opacity(0.5)
                            .brightness(workspace.isVisible ? 0.1 : 0)
                            .addBorder(workspace.isVisible ? .white : .clear, cornerRadius: 5)
                    )
            }
        }
        .padding(.horizontal, 4)
        .frame(maxHeight: 20)
    }

    var workSpaceMin: some View {
        HStack(spacing: 4) {
            ForEach(Workspace.all.filter { !$0.isEffectivelyEmpty || $0.isVisible }) { workspace in
                Text(workspace.name)
                    .shadow(radius: 3)
                    .font(
                        Font(
                            NSFont(name: config.fontFamily, size: config.fontSize)
                                ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                        )
                    )
                    .frame(minWidth: 20)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .opacity(0.5)
                            .brightness(workspace.isVisible ? 0.1 : 0)
                            .addBorder(workspace.isVisible ? .white : .clear, cornerRadius: 5)
                    )
            }
        }
        .padding(.horizontal, 4)
        .frame(maxHeight: 20)
    }

    var modeIndicator: some View {
        let modeText = activeMode?.takeIf { $0 != mainModeId }?.first?.lets { String($0) } ?? ""
        
        return Group {
            if !modeText.isEmpty {
                //This has to be a ZStack, otherwise the text doesnt get displayed
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 18, height: 18)
                    
                    Text(modeText)
                        .shadow(radius: 3)
                        .font(
                            Font(
                                NSFont(name: config.fontFamily, size: config.fontSize)
                                    ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
                            )
                        )
                }
            }
        }
    }


    var body: some View {
        // This is a bit weird, but otherwise the mode indicator won't show for some reason
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                modeIndicator
                    .frame(maxHeight: .infinity)
                
                if activeMode?.takeIf({ $0 != mainModeId }) != nil {
                    Spacer()
                        .frame(width: 5)
                }
                
                if viewModel.isEnabled {
                    switch config.workSpaceIndicatorStyle {
                    case .icon:
                        workSpaceSingle
                    case .horizontal_full:
                        workSpaceFull
                    case .horizontal_min:
                        workSpaceMin
                    }
                } else {
                    Image(systemName: "pause.fill")
                        .frame(height: config.fontSize)
                }
            }
        }
        .frame(maxHeight: 20)
    }
}

extension View {
    fileprivate func addBorder<S>(_ content: S, width: CGFloat = 1, cornerRadius: CGFloat) -> some View
    where S: ShapeStyle {
        let roundedRect = RoundedRectangle(cornerRadius: cornerRadius)
        return clipShape(roundedRect)
            .overlay(roundedRect.strokeBorder(content, lineWidth: width))
    }
}
