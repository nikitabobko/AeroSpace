import AppKit
import Common
import SwiftUI

private let maxPanelWidth: CGFloat = 1180
private let cardMinWidth: CGFloat = 250
private let cardMaxWidth: CGFloat = 330

/// Informational overlay that shows every window and the workspace it lives on.
/// Shown while the 'overview.hold-modifier' modifier is held down
public final class OverviewPanel: NSPanelHud {
    @MainActor public static var shared: OverviewPanel = OverviewPanel()
    private let model = OverviewModel()
    private var titlesTask: Task<(), any Error>? = nil

    override private init() {
        super.init()
        // The panel is informational. It must not swallow clicks that are meant for the windows underneath
        self.ignoresMouseEvents = true
    }

    func show() {
        model.workspaces = collectOverviewWorkspaces()
        let windowIds = model.workspaces.flatMap(\.windows).map(\.windowId).toSet()
        model.titles = model.titles.filter { windowIds.contains($0.key) } // Don't accumulate titles of closed windows
        let width = min(maxPanelWidth, mainMonitorInfo.width - 80)
        let hostingView = NSHostingView(rootView: OverviewView(model: model, width: width))
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: 0) // fittingSize needs the target width
        hostingView.layoutSubtreeIfNeeded()
        let height = min(hostingView.fittingSize.height, mainMonitorInfo.height - 60)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        self.contentView?.subviews.removeAll()
        self.contentView?.addSubview(hostingView)
        self.setFrame(
            NSRect(
                x: (mainMonitorInfo.width - width) / 2,
                y: (mainMonitorInfo.height - height) / 2,
                width: width,
                height: height,
            ),
            display: true,
        )
        self.orderFrontRegardless()
        prefetchTitles()
    }

    func hide() {
        titlesTask?.cancel()
        titlesTask = nil
        self.close()
    }

    /// Titles are AX requests. Don't block showing the panel on them, fill them in once they arrive.
    /// The layout doesn't depend on the title text, so late titles don't resize the panel
    private func prefetchTitles() {
        titlesTask?.cancel()
        titlesTask = Task.startUnstructured { @MainActor in
            for window in self.model.workspaces.flatMap(\.windows) {
                try checkCancellation()
                guard let title = try await Window.get(byId: window.windowId)?.getTitle(.nonCancellable) else { continue }
                self.model.titles[window.windowId] = title
            }
        }
    }
}

@MainActor private func collectOverviewWorkspaces() -> [OverviewWorkspaceModel] {
    let focus = focus
    // Workspace.all is sorted the same way as in 'list-workspaces'
    return Workspace.all
        .filter { !$0.allLeafWindowsRecursive.isEmpty || $0 == focus.workspace }
        .map { workspace in
            OverviewWorkspaceModel(
                name: workspace.name,
                monitorName: workspace.workspaceMonitor.name,
                isFocused: workspace == focus.workspace,
                windows: workspace.allLeafWindowsRecursive.map { window in
                    OverviewWindowModel(
                        windowId: window.windowId,
                        appName: window.app.name ?? "",
                        appBundleId: window.app.rawAppBundleId,
                        isFocused: window.windowId == focus.windowOrNil?.windowId,
                    )
                },
            )
        }
}

@MainActor final class OverviewModel: ObservableObject {
    @Published var workspaces: [OverviewWorkspaceModel] = []
    @Published var titles: [UInt32: String] = [:]
    private var icons: [String: NSImage] = [:]

    func icon(_ bundleId: String?) -> NSImage? {
        guard let bundleId else { return nil }
        if let cached = icons[bundleId] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleId] = icon
        return icon
    }
}

struct OverviewWorkspaceModel: Identifiable {
    let name: String
    let monitorName: String
    let isFocused: Bool
    let windows: [OverviewWindowModel]
    var id: String { name }
}

struct OverviewWindowModel: Identifiable {
    let windowId: UInt32
    let appName: String
    let appBundleId: String?
    let isFocused: Bool
    var id: UInt32 { windowId }
}

struct OverviewView: View {
    @ObservedObject var model: OverviewModel
    let width: CGFloat

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    private var cardColor: Color { Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.06) }
    private var showMonitorName: Bool { model.workspaces.map(\.monitorName).toSet().count > 1 }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: cardMinWidth, maximum: cardMaxWidth), spacing: 12)],
            alignment: .leading,
            spacing: 12,
        ) {
            ForEach(model.workspaces) { workspace in card(workspace) }
        }
        .padding(18)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }

    private func card(_ workspace: OverviewWorkspaceModel) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(workspace.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .frame(minWidth: 22, minHeight: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(workspace.isFocused ? Color.accentColor : Color.primary.opacity(0.12)),
                    )
                    .foregroundStyle(workspace.isFocused ? Color.white : Color.primary)
                if showMonitorName {
                    Text(workspace.monitorName).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(workspace.windows.count)").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            ForEach(workspace.windows) { window in row(window) }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(cardColor))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(workspace.isFocused ? Color.accentColor : Color.clear, lineWidth: 1.5),
        )
    }

    private func row(_ window: OverviewWindowModel) -> some View {
        HStack(spacing: 6) {
            if let icon = model.icon(window.appBundleId) {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(window.appName).font(.system(size: 11, weight: .medium)).lineLimit(1)
                // Reserve the line even before the title arrives, so that late titles don't resize the panel
                Text(model.titles[window.windowId] ?? " ")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(window.isFocused ? Color.accentColor.opacity(0.28) : Color.clear),
        )
    }
}
