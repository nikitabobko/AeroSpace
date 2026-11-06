import AppKit
import Common

final class CommandCenterWindow: NSWindow {
    private(set) var monitor: MonitorSnapshot
    private(set) var layout: CommandCenterLayout

    init(monitor: MonitorSnapshot) {
        self.monitor = monitor
        self.layout = CommandCenterLayout(monitor: monitor)
        super.init(contentRect: monitor.rect.toNSRect(), styleMask: [.borderless], backing: .buffered, defer: false)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        contentView = CommandCenterView(window: self)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Reflects a new snapshot of the same monitor. The caller redraws
    func update(_ monitor: MonitorSnapshot) {
        self.monitor = monitor
        self.layout = CommandCenterLayout(monitor: monitor)
    }

    /// Screen point (top-left origin, the same coordinate space as `Rect`)
    func screenPoint(of event: NSEvent) -> CGPoint {
        let point = convertPoint(toScreen: event.locationInWindow)
        return CGPoint(x: point.x, y: mainMonitorInfo.height - point.y)
    }
}

private final class CommandCenterView: NSView {
    private let commandCenterWindow: CommandCenterWindow
    private var mouseDownPoint: CGPoint? = nil
    /// What a drag would move if the mouse moved far enough
    private var mouseDownSource: DragSource? = nil

    init(window: CommandCenterWindow) {
        self.commandCenterWindow = window
        super.init(frame: NSRect(origin: .zero, size: window.frame.size))
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var layout: CommandCenterLayout { commandCenterWindow.layout }
    private var palette: CommandCenterPalette { CommandCenter.shared.palette }

    // MARK: - Mouse

    private func localPoint(of event: NSEvent) -> CGPoint { convert(event.locationInWindow, from: nil) }

    override func mouseMoved(with event: NSEvent) {
        CommandCenter.shared.setHover(layout.tile(at: localPoint(of: event))?.workspace.name)
    }

    override func mouseExited(with event: NSEvent) {
        CommandCenter.shared.setHover(nil)
    }

    override func mouseDown(with event: NSEvent) {
        let point = localPoint(of: event)
        mouseDownPoint = point
        if let (window, _) = layout.window(at: point) {
            mouseDownSource = .window(window)
        } else if let tile = layout.tile(at: point) {
            mouseDownSource = .workspace(tile.workspace.name)
        } else {
            mouseDownSource = nil
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = localPoint(of: event)
        if CommandCenter.shared.drag == nil {
            guard let mouseDownPoint, let mouseDownSource, hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y) > 4 else { return }
            CommandCenter.shared.beginDrag(mouseDownSource, at: commandCenterWindow.screenPoint(of: event))
        }
        CommandCenter.shared.updateDrag(to: commandCenterWindow.screenPoint(of: event))
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownPoint = nil
            mouseDownSource = nil
        }
        if CommandCenter.shared.drag != nil {
            Task.startUnstructured { @MainActor in await CommandCenter.shared.endDrag() }
            return
        }
        switch mouseDownSource {
            case .window(let window):
                Task.startUnstructured { @MainActor in await CommandCenter.shared.clickWindow(window) }
            case .workspace(let name):
                Task.startUnstructured { @MainActor in await CommandCenter.shared.clickWorkspace(name) }
            case nil:
                if layout.shelf?.contains(localPoint(of: event)) == true { return } // The shelf itself is not a button
                Task.startUnstructured { @MainActor in await CommandCenter.shared.close(restoreFocus: true) }
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        palette.backgroundColor.nsColor.setFill()
        bounds.fill()

        let drag = CommandCenter.shared.drag
        let hover = drag == nil ? CommandCenter.shared.hover : nil
        for tile in layout.tiles {
            if drag?.source == .workspace(tile.workspace.name) {
                drawDraggedTileSlot(tile)
                continue
            }
            let isDropTarget = drag?.target == .workspace(tile.workspace.name) || drag?.target == .swap(tile.workspace.name)
            drawTile(tile, isDropTarget: isDropTarget, isHovered: hover == tile.workspace.name)
        }
        if let shelf = layout.shelf {
            palette.workspaceColor.nsColor.setFill()
            NSBezierPath(roundedRect: shelf, xRadius: CommandCenterLayout.tileRadius, yRadius: CommandCenterLayout.tileRadius).fill()
            for (window, frame) in layout.shelfChips {
                drawChip(window, in: frame, dimmed: false)
            }
        }
        if let drag {
            drawDropTarget(drag)
            drawGhost(drag)
        }
    }

    /// The tile has no border. The ring outside of the focused tile and the badge carry the state, so the grid never shifts
    private func drawTile(_ tile: CommandCenterLayout.Tile, isDropTarget: Bool, isHovered: Bool) {
        let workspace = tile.workspace
        if workspace.isFocused || isDropTarget {
            drawRing(around: tile.frame, dashed: isDropTarget && !workspace.isFocused)
        }

        (isHovered ? palette.hoverColor : palette.workspaceColor).nsColor.setFill()
        NSBezierPath(roundedRect: tile.frame, xRadius: CommandCenterLayout.tileRadius, yRadius: CommandCenterLayout.tileRadius).fill()

        for (window, frame) in tile.windows {
            drawWindow(window, in: frame)
        }
        for (window, frame) in tile.chips {
            drawChip(window, in: frame, dimmed: true)
        }

        let badgeColor = workspace.isFocused ? palette.activeColor : workspace.isVisible ? palette.visibleColor : palette.inactiveColor
        drawBadge(tile, color: badgeColor)
    }

    /// Where the dragged tile was: a dashed outline, so the user sees what they picked up
    private func drawDraggedTileSlot(_ tile: CommandCenterLayout.Tile) {
        let path = NSBezierPath(roundedRect: tile.frame.insetBy(dx: 1, dy: 1), xRadius: CommandCenterLayout.tileRadius - 1, yRadius: CommandCenterLayout.tileRadius - 1)
        path.lineWidth = 2
        path.dash()
        palette.inactiveColor.nsColor.setStroke()
        path.stroke()
        drawBadge(tile, color: palette.inactiveColor)
    }

    private func drawRing(around frame: CGRect, dashed: Bool) {
        let width = palette.ringWidth
        let ring = NSBezierPath(
            roundedRect: frame.insetBy(dx: -width / 2, dy: -width / 2),
            xRadius: CommandCenterLayout.tileRadius + width / 2,
            yRadius: CommandCenterLayout.tileRadius + width / 2,
        )
        ring.lineWidth = width
        if dashed { ring.dash() }
        palette.activeColor.nsColor.setStroke()
        ring.stroke()
    }

    private func drawBadge(_ tile: CommandCenterLayout.Tile, color: ArgbColor) {
        color.nsColor.setFill()
        NSBezierPath(ovalIn: tile.badge).fill()
        drawText(
            tile.workspace.name,
            in: tile.badge.offsetBy(dx: 0, dy: (tile.badge.height - 15) / 2),
            font: .systemFont(ofSize: 12, weight: .bold),
            color: color.isLight ? ArgbColor(0xFF11_1111) : palette.textColor,
            alignment: .center,
        )
    }

    private func drawWindow(_ window: WindowSnapshot, in frame: CGRect) {
        let isDragged = CommandCenter.shared.drag?.source == .window(window)
        let radius = CommandCenterLayout.windowRadius
        palette.windowColor.nsColor.withAlphaComponent(isDragged ? 0.3 : 1).setFill()
        NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).fill()
        if window.isFocused {
            let path = NSBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 1), xRadius: radius - 1, yRadius: radius - 1)
            path.lineWidth = 2
            palette.activeColor.nsColor.setStroke()
            path.stroke()
        }
        if isDragged { return }

        let iconSize = min(40, frame.height * 0.4, frame.width * 0.4)
        let textHeight: CGFloat = frame.height > iconSize + 36 ? 16 : 0
        let iconOrigin = CGPoint(x: frame.midX - iconSize / 2, y: frame.midY - (iconSize + textHeight) / 2)
        window.icon?.drawFlipped(in: CGRect(origin: iconOrigin, size: CGSize(width: iconSize, height: iconSize)))
        if textHeight > 0 {
            let title = CommandCenter.shared.titles[window.windowId]?.takeIf { !$0.isEmpty } ?? window.appName
            drawText(
                title,
                in: CGRect(x: frame.minX + 6, y: iconOrigin.y + iconSize + 4, width: frame.width - 12, height: textHeight),
                font: .systemFont(ofSize: 11),
                alignment: .center,
            )
        }
    }

    /// A window without a place in the layout: its icon in a small bordered square
    private func drawChip(_ window: WindowSnapshot, in frame: CGRect, dimmed: Bool) {
        let isDragged = CommandCenter.shared.drag?.source == .window(window)
        let alpha: CGFloat = isDragged ? 0.3 : dimmed ? 0.6 : 1
        let radius = CommandCenterLayout.chipRadius
        let path = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
        palette.windowColor.nsColor.withAlphaComponent(alpha).setFill()
        path.fill()
        palette.visibleColor.nsColor.withAlphaComponent(0.5 * alpha).setStroke()
        path.lineWidth = 1
        path.stroke()
        if isDragged { return }
        let iconSize: CGFloat = 20
        let icon = CGRect(x: frame.midX - iconSize / 2, y: frame.midY - iconSize / 2, width: iconSize, height: iconSize)
        window.icon?.drawFlipped(in: icon, alpha: alpha)
    }

    private func drawDropTarget(_ drag: CommandCenter.Drag) {
        guard let target = drag.target else { return }
        palette.activeColor.nsColor.setStroke()
        palette.activeColor.nsColor.setFill()
        switch target {
            case .workspace: break // The ring is drawn in drawTile
            case .swap(let name):
                // The ring is drawn in drawTile. The glyph says what the drop does
                guard let tile = layout.tiles.first(where: { $0.workspace.name == name }) else { return }
                drawSwapGlyph(at: CGPoint(x: tile.frame.midX, y: tile.frame.midY))
            case .before(let window), .after(let window):
                guard let frame = layout.frame(of: window), let orientation = window.parentOrientation else { return }
                let isBefore = if case .before = target { true } else { false }
                let thickness: CGFloat = 4
                let gap = CommandCenterLayout.padding
                let line = switch (orientation, isBefore) {
                    case (.h, true): CGRect(x: frame.minX - gap / 2 - thickness / 2, y: frame.minY, width: thickness, height: frame.height)
                    case (.h, false): CGRect(x: frame.maxX + gap / 2 - thickness / 2, y: frame.minY, width: thickness, height: frame.height)
                    case (.v, true): CGRect(x: frame.minX, y: frame.minY - gap / 2 - thickness / 2, width: frame.width, height: thickness)
                    case (.v, false): CGRect(x: frame.minX, y: frame.maxY + gap / 2 - thickness / 2, width: frame.width, height: thickness)
                }
                NSBezierPath(roundedRect: line, xRadius: 2, yRadius: 2).fill()
            case .join(let window):
                guard let frame = layout.frame(of: window) else { return }
                let radius = CommandCenterLayout.windowRadius
                let path = NSBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 1), xRadius: radius - 1, yRadius: radius - 1)
                path.lineWidth = 2
                path.stroke()
        }
    }

    /// Two arrows pointing at each other in a filled circle
    private func drawSwapGlyph(at center: CGPoint) {
        let diameter: CGFloat = 44
        palette.activeColor.nsColor.setFill()
        NSBezierPath(ovalIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)).fill()
        let stroke = NSBezierPath()
        stroke.lineWidth = 2.5
        stroke.lineCapStyle = .round
        stroke.lineJoinStyle = .round
        // Top arrow points right, bottom arrow points left
        let x0 = center.x - 10, x1 = center.x + 10
        let top = center.y - 5, bottom = center.y + 5
        stroke.move(to: CGPoint(x: x0, y: top)); stroke.line(to: CGPoint(x: x1, y: top))
        stroke.move(to: CGPoint(x: x1 - 4, y: top - 4)); stroke.line(to: CGPoint(x: x1, y: top)); stroke.line(to: CGPoint(x: x1 - 4, y: top + 4))
        stroke.move(to: CGPoint(x: x1, y: bottom)); stroke.line(to: CGPoint(x: x0, y: bottom))
        stroke.move(to: CGPoint(x: x0 + 4, y: bottom - 4)); stroke.line(to: CGPoint(x: x0, y: bottom)); stroke.line(to: CGPoint(x: x0 + 4, y: bottom + 4))
        (palette.activeColor.isLight ? ArgbColor(0xFF11_1111) : palette.textColor).nsColor.setStroke()
        stroke.stroke()
    }

    private func drawGhost(_ drag: CommandCenter.Drag) {
        let monitor = commandCenterWindow.monitor.rect
        let center = CGPoint(x: drag.point.x - monitor.topLeftX, y: drag.point.y - monitor.topLeftY)
        switch drag.source {
            case .window(let window):
                guard let frame = layout.frame(of: window) else { return } // The ghost is drawn by the monitor the drag started on
                let size = CGSize(width: min(frame.width, 160), height: min(frame.height, 100))
                let ghost = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
                let radius = window.isInLayout ? CommandCenterLayout.windowRadius : CommandCenterLayout.chipRadius
                let path = NSBezierPath(roundedRect: ghost, xRadius: radius, yRadius: radius)
                palette.windowColor.nsColor.withAlphaComponent(0.9).setFill()
                path.fill()
                palette.activeColor.nsColor.setStroke()
                path.lineWidth = 2
                path.stroke()
                let iconSize = min(32, size.height * 0.6)
                window.icon?.drawFlipped(in: CGRect(x: ghost.midX - iconSize / 2, y: ghost.midY - iconSize / 2, width: iconSize, height: iconSize))
            case .workspace(let name):
                // The whole tile follows the mouse, slightly transparent
                guard let tile = layout.tiles.first(where: { $0.workspace.name == name }), let context = NSGraphicsContext.current else { return }
                context.saveGraphicsState()
                context.cgContext.translateBy(x: center.x - tile.frame.midX, y: center.y - tile.frame.midY)
                context.cgContext.setAlpha(0.9)
                context.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
                drawTile(tile, isDropTarget: false, isHovered: false)
                context.cgContext.endTransparencyLayer()
                context.restoreGraphicsState()
        }
    }

    private func drawText(_ text: String, in rect: CGRect, font: NSFont, color: ArgbColor? = nil, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: (color ?? palette.textColor).nsColor,
            .paragraphStyle: paragraph,
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
}

extension Rect {
    /// AppKit coordinates: (0, 0) is the bottom left corner of the main monitor, y-axis goes up
    func toNSRect() -> NSRect {
        NSRect(x: topLeftX, y: mainMonitorInfo.height - topLeftY - height, width: width, height: height)
    }
}

extension NSBezierPath {
    /// The dash pattern of drop targets and of the slot of a dragged tile
    fileprivate func dash() {
        var pattern: [CGFloat] = [8, 6]
        unsafe setLineDash(&pattern, count: 2, phase: 0)
    }
}

extension NSImage {
    /// `draw(in:)` draws upside down in flipped views
    fileprivate func drawFlipped(in rect: CGRect, alpha: CGFloat = 1) {
        draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha, respectFlipped: true, hints: nil)
    }
}
