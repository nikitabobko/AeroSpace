import AppKit
import SwiftUI

@MainActor
final class TabHeadersPanel: NSPanelHud {
    private var hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private weak var hostingContainerView: NSView?

    override init() {
        super.init()
        self.ignoresMouseEvents = false
        self.hasShadow = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.contentView = NSView(frame: .zero)
    }

    func update(snapshot: TabHeaderSnapshot) {
        let rootView = AnyView(TabHeaderStripView(snapshot: snapshot))
        if contentView == nil {
            contentView = NSView(frame: .zero)
        }
        guard let contentView else { return }
        if hostingContainerView !== contentView {
            hostingView.removeFromSuperview()
            hostingView = NSHostingView(rootView: rootView)
            contentView.addSubview(hostingView)
            hostingContainerView = contentView
        } else {
            hostingView.rootView = rootView
        }
        hostingView.frame = NSRect(origin: .zero, size: snapshot.headerFrame.size)
        setFrame(snapshot.headerFrame.nsRect, display: true)
        orderFrontRegardless()
    }
}

@MainActor
final class TabHeadersPanelController {
    static let shared = TabHeadersPanelController()

    private var panels: [ObjectIdentifier: TabHeadersPanel] = [:]

    private init() {}

    func refresh(with snapshots: [TabHeaderSnapshot]) {
        let nextIds = Set(snapshots.map(\.id))
        for (id, panel) in panels where !nextIds.contains(id) {
            panel.close()
            panels.removeValue(forKey: id)
        }
        for snapshot in snapshots {
            let panel: TabHeadersPanel
            if let existing = panels[snapshot.id] {
                panel = existing
            } else {
                panel = TabHeadersPanel()
                panels[snapshot.id] = panel
            }
            panel.update(snapshot: snapshot)
        }
    }

    func closeAll() {
        for (_, panel) in panels {
            panel.close()
        }
        panels = [:]
    }
}

private struct TabHeaderStripView: View {
    let snapshot: TabHeaderSnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: TabHeaderMetrics.cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.75))
            ForEach(snapshot.items) { item in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: TabHeaderMetrics.cornerRadius, style: .continuous)
                        .fill(item.isActive ? Color.white.opacity(0.18) : Color.white.opacity(0.08))

                    Text(item.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.system(size: 12, weight: item.isActive ? .semibold : .regular))
                        .foregroundStyle(item.isActive ? Color.white : Color.white.opacity(0.85))
                        .padding(.leading, TabHeaderMetrics.titleHorizontalInset)
                        .padding(.trailing, TabHeaderMetrics.titleHorizontalInset)
                        .frame(
                            width: item.titleFrame.width,
                            height: item.titleFrame.height,
                            alignment: .leading,
                        )
                        .offset(
                            x: item.titleFrame.topLeftX - item.frame.topLeftX,
                            y: item.titleFrame.topLeftY - item.frame.topLeftY,
                        )

                    Button {
                        activate(item.targetWindow)
                    } label: {
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: item.frame.width, height: item.frame.height)

                    Button {
                        close(item.targetWindow)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(item.isActive ? Color.white.opacity(0.92) : Color.white.opacity(0.75))
                            .frame(width: item.closeButtonFrame.width, height: item.closeButtonFrame.height)
                            .background(
                                Circle()
                                    .fill(item.isActive ? Color.white.opacity(0.12) : Color.clear),
                            )
                    }
                    .buttonStyle(.plain)
                    .offset(
                        x: item.closeButtonFrame.topLeftX - item.frame.topLeftX,
                        y: item.closeButtonFrame.topLeftY - item.frame.topLeftY,
                    )
                }
                .frame(width: item.frame.width, height: item.frame.height, alignment: .topLeading)
                .offset(x: item.frame.topLeftX, y: item.frame.topLeftY)
            }
        }
        .frame(width: snapshot.headerFrame.width, height: snapshot.headerFrame.height, alignment: .topLeading)
    }

    private func activate(_ window: Window) {
        Task { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            TabHeaderInteractionState.shared.markInteraction()
            try await runLightSession(.menuBarButton, token) {
                guard focus.windowOrNil != window else { return }
                guard window.focusWindow() else { return }
                window.nativeFocus()
            }
        }
    }

    private func close(_ window: Window) {
        Task { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            TabHeaderInteractionState.shared.markInteraction()
            try await runLightSession(.menuBarButton, token) {
                window.closeAxWindow()
            }
        }
    }
}
