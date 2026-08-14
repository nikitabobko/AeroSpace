import AppKit
import SwiftUI

/// A transparent, click-through overlay panel that draws a colored border around
/// the currently focused window. Native replacement for external border tools
/// (e.g. JankyBorders) for the common "highlight the focused window" use case.
final class FocusedWindowBorderPanel: NSPanel {
    @MainActor static var shared: FocusedWindowBorderPanel = FocusedWindowBorderPanel()
    private var hosting: NSHostingView<FocusedWindowBorderView>?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    @MainActor func show(rect: Rect, colorHex: String, width: Int, opacityPercent: Int, cornerRadius: Int, inset: Int) {
        let w = CGFloat(width)
        // `inset` pulls the stroke that many points back INTO the window. With inset 0
        // the stroke sits fully outside (the historical behavior). With inset > 0 the
        // border overlaps the window's own rounded corner, so the real corner masks any
        // mismatch between our configured radius and the window's true radius — no gap
        // shows even when the exact per-window radius is unknown. Clamp so we never push
        // past the inner edge of the stroke.
        let inset = CGFloat(min(max(inset, 0), width))
        let grow = w - inset // net expansion beyond the window edge on every side
        // AeroSpace Rect is top-left origin (y grows down). Convert back to Cocoa
        // (bottom-left origin) and expand by `grow` on every side.
        let cocoaY = mainMonitor.height - rect.topLeftY - rect.height
        let frame = NSRect(
            x: rect.topLeftX - grow,
            y: cocoaY - grow,
            width: rect.width + 2 * grow,
            height: rect.height + 2 * grow,
        )

        // Combine the color's own alpha with the separate opacity percentage.
        let baseColor = NSColor(argbHex: colorHex) ?? .systemGreen
        let opacityFactor = CGFloat(min(max(opacityPercent, 0), 100)) / 100
        let finalColor = baseColor.withAlphaComponent(baseColor.alphaComponent * opacityFactor)
        // Outer radius = the window's apparent corner radius plus however far the stroke's
        // outer edge sits outside the window edge (`grow`), so the outer edge stays
        // concentric with the window corner.
        let view = FocusedWindowBorderView(
            color: Color(nsColor: finalColor),
            width: w,
            cornerRadius: CGFloat(cornerRadius) + grow,
        )
        if let hosting {
            hosting.rootView = view
        } else {
            let hostingView = NSHostingView(rootView: view)
            contentView?.addSubview(hostingView)
            hosting = hostingView
        }
        hosting?.frame = NSRect(origin: .zero, size: frame.size)
        setFrame(frame, display: true)
        orderFrontRegardless()
    }

    @MainActor func hide() {
        orderOut(nil)
    }
}

struct FocusedWindowBorderView: View {
    let color: Color
    let width: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(color, lineWidth: width)
    }
}

extension NSColor {
    /// Parse an `0xAARRGGBB` (or `0xRRGGBB`) hex string, matching the format used
    /// by JankyBorders config (e.g. `0xff12B981`).
    convenience init?(argbHex: String) {
        var str = argbHex.trimmingCharacters(in: .whitespaces).lowercased()
        if str.hasPrefix("0x") { str.removeFirst(2) }
        if str.hasPrefix("#") { str.removeFirst() }
        guard let value = UInt64(str, radix: 16) else { return nil }
        let a: CGFloat
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        switch str.count {
            case 8: // AARRGGBB
                a = CGFloat((value >> 24) & 0xFF) / 255
                r = CGFloat((value >> 16) & 0xFF) / 255
                g = CGFloat((value >> 8) & 0xFF) / 255
                b = CGFloat(value & 0xFF) / 255
            case 6: // RRGGBB
                a = 1
                r = CGFloat((value >> 16) & 0xFF) / 255
                g = CGFloat((value >> 8) & 0xFF) / 255
                b = CGFloat(value & 0xFF) / 255
            default:
                return nil
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

/// Update (or hide) the focused-window border to match the current focus and config.
@MainActor func refreshFocusedWindowBorder() async {
    guard config.focusedWindowBorder, let window = focus.windowOrNil else {
        FocusedWindowBorderPanel.shared.hide()
        return
    }
    guard let rect = try? await window.getAxRect(), rect.width > 0, rect.height > 0 else {
        FocusedWindowBorderPanel.shared.hide()
        return
    }
    FocusedWindowBorderPanel.shared.show(
        rect: rect,
        colorHex: config.focusedWindowBorderColor,
        width: config.focusedWindowBorderWidth,
        opacityPercent: config.focusedWindowBorderOpacity,
        cornerRadius: config.focusedWindowBorderRadius,
        inset: config.focusedWindowBorderInset,
    )
}
