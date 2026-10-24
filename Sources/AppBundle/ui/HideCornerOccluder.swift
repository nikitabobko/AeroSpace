import AppKit
import Common

/// Covers the 1-pixel on-screen sliver where `MacWindow.hideInCorner` parks
/// windows belonging to inactive workspaces so that macOS `WindowServer`
/// marks those windows occluded (`NSWindow.occlusionState` without `.visible`)
/// instead of compositing all off-workspace windows on every display refresh.
@MainActor
final class HideCornerOccluder {
    static let shared = HideCornerOccluder()

    private var panelsByMonitorOrigin: [CGPoint: NSPanel] = [:]

    private init() {}

    func update(
        monitors: [MonitorInfo],
        monitorToOptimalHideCorner: [CGPoint: OptimalHideCorner],
        monitorsWithHiddenWindows: Set<CGPoint>,
    ) {
        if isUnitTest || serverArgs.isReadOnly || !TrayMenuModel.shared.isEnabled {
            hideAll()
            return
        }

        let mainMonitorHeight = mainMonitorInfo.height
        var activeOrigins: Set<CGPoint> = []

        for monitor in monitors {
            let origin = monitor.rect.topLeftCorner
            guard monitorsWithHiddenWindows.contains(origin) else { continue }
            activeOrigins.insert(origin)

            let corner = monitorToOptimalHideCorner[origin] ?? .bottomRightCorner
            let frame = Self.occluderAppKitFrame(
                for: monitor,
                corner: corner,
                mainMonitorHeight: mainMonitorHeight,
            )
            let panel: NSPanel
            if let existing = panelsByMonitorOrigin[origin] {
                panel = existing
            } else {
                panel = Self.makePanel()
                panelsByMonitorOrigin[origin] = panel
            }
            if panel.frame != frame {
                panel.setFrame(frame, display: true)
            }
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        }

        for (origin, panel) in panelsByMonitorOrigin where !activeOrigins.contains(origin) {
            panel.orderOut(nil)
            panelsByMonitorOrigin.removeValue(forKey: origin)
        }
    }

    func hideAll() {
        for (_, panel) in panelsByMonitorOrigin {
            panel.orderOut(nil)
        }
        panelsByMonitorOrigin.removeAll()
    }

    // macOS clamps corner-hidden windows vertically so their titlebar height
    // (~28-41px) remains on-screen while leaving 1px horizontally inside
    // `monitor.visibleRect`. A 2px-wide opaque strip along the bottom 64px of
    // the hide corner fully occludes the clamped sliver while remaining
    // visually imperceptible and click-through.
    private static let occluderWidth: CGFloat = 2
    private static let occluderHeightAboveVisibleBottom: CGFloat = 64

    static func occluderAppKitFrame(
        for monitor: MonitorInfo,
        corner: OptimalHideCorner,
        mainMonitorHeight: CGFloat,
    ) -> NSRect {
        let x: CGFloat = switch corner {
            case .bottomLeftCorner:
                monitor.visibleRect.minX
            case .bottomRightCorner:
                max(monitor.visibleRect.minX, monitor.visibleRect.maxX - occluderWidth)
        }
        let topY = max(monitor.visibleRect.minY, monitor.visibleRect.maxY - occluderHeightAboveVisibleBottom)
        let bottomY = max(monitor.visibleRect.maxY, monitor.rect.maxY)
        let height = max(1, bottomY - topY)
        let appKitY = mainMonitorHeight - bottomY
        return NSRect(x: x, y: appKitY, width: occluderWidth, height: height)
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false,
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.isOpaque = true
        panel.hasShadow = false
        panel.alphaValue = 1
        panel.backgroundColor = .black
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.black.cgColor
        panel.contentView?.layer?.isOpaque = true
        return panel
    }
}
