import AppKit
import Common
import SwiftUI

@MainActor
struct CenteredWorkspaceBar: View {
    @ObservedObject var viewModel: TrayMenuModel
    let barHeight: CGFloat
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    // Derived sizing from bar height
    private var itemHeight: CGFloat { max(16, barHeight - 4) }
    private var iconSize: CGFloat { max(12, itemHeight - 6) }
    private let workspaceSpacing: CGFloat = 8
    private let windowSpacing: CGFloat = 2
    private let cornerRadius: CGFloat = 6
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
    
    private var activeBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
    }
    
    private var borderColor: Color {
        // Accent color 0xffc4a7e7 (ARGB). Alpha=1.0, RGB=c4 a7 e7
        Color(red: 196/255.0, green: 167/255.0, blue: 231/255.0)
    }
    
    var body: some View {
        HStack(spacing: workspaceSpacing) {
            ForEach(viewModel.centeredBarWorkspaces, id: \.workspace.name) { item in
                WorkspaceItemView(
                    item: item,
                    iconSize: iconSize,
                    itemHeight: itemHeight,
                    windowSpacing: windowSpacing,
                    cornerRadius: cornerRadius,
                    backgroundColor: backgroundColor,
                    activeBackgroundColor: activeBackgroundColor,
                    borderColor: borderColor
                )
            }
        }
        .padding(.horizontal, 4)
        .frame(height: itemHeight + 4)
    }
}

@MainActor
private struct WorkspaceItemView: View {
    let item: CenteredBarWorkspaceItem
    let iconSize: CGFloat
    let itemHeight: CGFloat
    let windowSpacing: CGFloat
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let activeBackgroundColor: Color
    let borderColor: Color
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: windowSpacing) {
            // Workspace identifier
            if viewModel.showWorkspaceNumbers {
                Text(item.workspace.name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(item.isFocused ? borderColor : .secondary)
                    .frame(minWidth: 16)
                
                if !item.windows.isEmpty {
                    Divider()
                        .frame(height: iconSize)
                        .padding(.horizontal, 2)
                }
            }
            
            // Window icons
            ForEach(item.windows, id: \.windowId) { window in
                WindowIconView(
                    window: window,
                    workspace: item.workspace,
                    iconSize: iconSize,
                    isFocused: window.isFocused,
                    isInFocusedWorkspace: item.isFocused
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .frame(height: itemHeight)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(item.isFocused ? activeBackgroundColor : (isHovered ? backgroundColor : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(item.isFocused ? borderColor : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            focusWorkspace(item.workspace)
        }
    }
    
    private var viewModel: TrayMenuModel {
        TrayMenuModel.shared
    }
    
    private func focusWorkspace(_ workspace: Workspace) {
        Task {
            if let token: RunSessionGuard = .isServerEnabled {
                try await runSession(.menuBarButton, token) { 
                    _ = workspace.focusWorkspace() 
                }
            }
        }
    }
}

@MainActor
private struct WindowIconView: View {
    let window: CenteredBarWindowItem
    let workspace: Workspace
    let iconSize: CGFloat
    let isFocused: Bool
    let isInFocusedWorkspace: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        Group {
            if let icon = window.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: iconSize, height: iconSize)
        .opacity(opacity)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            focusWindow()
        }
        .help(window.appName ?? "Unknown App")
    }
    
    private var opacity: Double {
        if isFocused {
            return 1.0
        } else if isInFocusedWorkspace {
            return 0.6
        } else {
            return 0.8
        }
    }
    
    private func focusWindow() {
        Task {
            if let token: RunSessionGuard = .isServerEnabled {
                try await runSession(.menuBarButton, token) {
                    // First focus the workspace
                    _ = workspace.focusWorkspace()
                    // Then focus the specific window
                    if let macWindow = workspace.allLeafWindowsRecursive.first(where: { $0.windowId == window.windowId }) {
                        macWindow.nativeFocus()
                    }
                }
            }
        }
    }
}

// Data models for the centered bar
struct CenteredBarWorkspaceItem {
    let workspace: Workspace
    let isFocused: Bool
    let windows: [CenteredBarWindowItem]
}

struct CenteredBarWindowItem {
    let windowId: UInt32
    let appName: String?
    let icon: NSImage?
    let isFocused: Bool
}

// Extension to prepare data for centered bar
@MainActor
extension TrayMenuModel {
    var showWorkspaceNumbers: Bool {
        experimentalUISettings.centeredBarShowNumbers
    }
    
    var centeredBarWorkspaces: [CenteredBarWorkspaceItem] {
        let focus = focus
        // Show all workspaces, not just visible ones
        let allWorkspaces = Workspace.all.sorted()
        
        return allWorkspaces.map { workspace in
            let windows = workspace.allLeafWindowsRecursive.map { window in
                let icon: NSImage?
                if let macWindow = window as? MacWindow {
                    icon = macWindow.macApp.nsApp.icon
                } else {
                    icon = nil
                }
                
                return CenteredBarWindowItem(
                    windowId: window.windowId,
                    appName: window.app.name,
                    icon: icon,
                    isFocused: window == focus.windowOrNil
                )
            }
            
            return CenteredBarWorkspaceItem(
                workspace: workspace,
                isFocused: workspace == focus.workspace,
                windows: windows
            )
        }
    }
}
