import AppKit
import SwiftUI

/// Apple-style transient overlay shown when the focused workspace changes.
/// Modeled after `VolumePanel`: a borderless HUD panel hosting a SwiftUI view,
/// auto-dismissed by a timer with a fade-out.
public final class WorkspaceHud: NSPanelHud {
    @MainActor public static var shared: WorkspaceHud = WorkspaceHud()
    private var timer: Timer?
    private let panelSize = NSSize(width: 200, height: 200)

    override private init() {
        super.init()
    }

    @MainActor public func show(workspace: String, monitorScreenId: Int, durationMs: Int) {
        timer?.invalidate()
        contentView?.subviews.removeAll()

        let hostingView = NSHostingView(rootView: WorkspaceHudView(workspace: workspace))
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        contentView?.addSubview(hostingView)

        // Center on the monitor the workspace lives on (Cocoa/bottom-left coords).
        let screenFrame = NSScreen.screens.getOrNil(atIndex: monitorScreenId - 1)?.frame
            ?? NSScreen.main?.frame
            ?? NSRect(x: 0, y: 0, width: panelSize.width, height: panelSize.height)
        let origin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.midY - panelSize.height / 2,
        )
        setFrame(NSRect(origin: origin, size: panelSize), display: true)

        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            self.animator().alphaValue = 1
        }
        startTimer(durationMs: durationMs)
    }

    private func startTimer(durationMs: Int) {
        timer = .scheduledTimer(withTimeInterval: Double(durationMs) / 1000, repeats: false) { _ in
            Task { @MainActor [weak self] in self?.fadeOut() }
        }
    }

    @MainActor private func fadeOut() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            self.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in self?.close() }
        }
    }
}

struct WorkspaceHudView: View {
    let workspace: String

    var body: some View {
        VStack(spacing: 12) {
            Text(workspace)
                .font(.system(size: 92, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.35)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .frame(maxWidth: 150)
            Text("WORKSPACE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(.secondary)
        }
        .frame(width: 200, height: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1),
        )
    }
}
