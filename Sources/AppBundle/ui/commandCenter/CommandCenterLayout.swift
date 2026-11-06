import AppKit
import Common

/// Pure geometry of the command center on one monitor: where workspace tiles, window thumbnails, chips and the shelf go
///
/// Tiles are laid out in a dense grid. All tiles have the same size and the aspect ratio of the monitor.
/// The grid is centered on the monitor as a block, and a short last row is centered too.
/// Above every tile sits its badge with the workspace name.
/// Inside a tile, the windows are normalized so that the padding between the tile edge and a window
/// and the gutter between two windows is always `padding`, whatever the gaps on the real desktop are.
/// Windows without a place in the layout are chips in the bottom left corner of their tile.
/// Minimized windows are chips on the shelf at the bottom of the monitor.
struct CommandCenterLayout {
    let tiles: [Tile]
    /// nil when there are no minimized windows to show on this monitor
    let shelf: CGRect?
    let shelfChips: [(window: WindowSnapshot, frame: CGRect)]

    struct Tile {
        let workspace: WorkspaceSnapshot
        /// In view coordinates (top-left origin)
        let frame: CGRect
        let windows: [(window: WindowSnapshot, frame: CGRect)]
        let chips: [(window: WindowSnapshot, frame: CGRect)]

        /// The circle with the workspace name. Sits `padding` above the tile, left-aligned with it
        var badge: CGRect {
            let d = CommandCenterLayout.badgeDiameter
            return CGRect(x: frame.minX, y: frame.minY - CommandCenterLayout.padding - d, width: d, height: d)
        }

        /// The tile together with its badge
        var footprint: CGRect { frame.union(badge) }
    }

    /// Minimum distance between the grid and the monitor edges
    static let margin: CGFloat = 48
    /// Distance between tile footprints, both horizontally and vertically, and between the grid and the shelf
    static let gap: CGFloat = 24
    /// Distance between the tile edge and a window, between two windows, between the badge and the tile, and around chips
    static let padding: CGFloat = 8
    static let tileRadius: CGFloat = 16
    /// Concentric with the tile corner: tileRadius - padding
    static let windowRadius: CGFloat = 8
    static let badgeDiameter: CGFloat = 24
    static let chipSize: CGFloat = 36
    static let chipRadius: CGFloat = 10
    static let shelfHeight: CGFloat = chipSize + 2 * padding
    /// Width of the ring around the focused tile when JankyBorders doesn't dictate it
    static let defaultRingWidth: CGFloat = 4

    init(monitor: MonitorSnapshot) {
        let workspaces = monitor.workspaces
        let bounds = CGSize(width: monitor.rect.width, height: monitor.rect.height)

        let hasShelf = !monitor.shelf.isEmpty
        if hasShelf {
            let width = CGFloat(monitor.shelf.count) * Self.chipSize + CGFloat(monitor.shelf.count + 1) * Self.padding
            let shelf = CGRect(x: ((bounds.width - width) / 2).rounded(), y: bounds.height - Self.margin - Self.shelfHeight, width: width, height: Self.shelfHeight)
            self.shelf = shelf
            self.shelfChips = monitor.shelf.enumerated().map { index, window in
                (window, CGRect(x: shelf.minX + Self.padding + CGFloat(index) * (Self.chipSize + Self.padding), y: shelf.minY + Self.padding, width: Self.chipSize, height: Self.chipSize))
            }
        } else {
            self.shelf = nil
            self.shelfChips = []
        }

        guard !workspaces.isEmpty else {
            tiles = []
            return
        }
        // The grid lives between the top margin and the shelf (or the bottom margin)
        let gridTop = Self.margin
        let gridBottom = bounds.height - Self.margin - (hasShelf ? Self.shelfHeight + Self.gap : 0)
        let badgeHeight = Self.badgeDiameter + Self.padding
        let (rows, columns, tileSize) = Self.grid(count: workspaces.count, width: bounds.width, height: gridBottom - gridTop, aspectRatio: bounds.width / bounds.height, extraRowHeight: badgeHeight)
        let blockHeight = CGFloat(rows) * (tileSize.height + badgeHeight) + CGFloat(rows - 1) * Self.gap
        let originY = (gridTop + (gridBottom - gridTop - blockHeight) / 2).rounded()

        tiles = workspaces.enumerated().map { index, workspace in
            let column = index % columns
            let row = index / columns
            let tilesInRow = min(columns, workspaces.count - row * columns)
            let rowWidth = CGFloat(tilesInRow) * tileSize.width + CGFloat(tilesInRow - 1) * Self.gap
            let rowX = ((bounds.width - rowWidth) / 2).rounded()
            let frame = CGRect(
                origin: CGPoint(
                    x: rowX + CGFloat(column) * (tileSize.width + Self.gap),
                    y: originY + CGFloat(row) * (tileSize.height + badgeHeight + Self.gap) + badgeHeight,
                ),
                size: tileSize,
            )
            let chips = workspace.chips.enumerated().map { index, window in
                (window, CGRect(
                    x: frame.minX + Self.padding + CGFloat(index) * (Self.chipSize + Self.padding),
                    y: frame.maxY - Self.padding - Self.chipSize,
                    width: Self.chipSize,
                    height: Self.chipSize,
                ))
            }
            return Tile(workspace: workspace, frame: frame, windows: Self.windows(of: workspace, in: frame, monitor: monitor.rect), chips: chips)
        }
    }

    /// The grid with the biggest tiles: for every number of rows, the tiles are as wide as the monitor allows,
    /// unless the rows don't fit, in which case they are as tall as the available height allows.
    /// `height` is the height available to the grid (the monitor minus margins and shelf), `aspectRatio` is the monitor's
    private static func grid(count: Int, width: CGFloat, height: CGFloat, aspectRatio: CGFloat, extraRowHeight: CGFloat) -> (rows: Int, columns: Int, tileSize: CGSize) {
        var best: (rows: Int, columns: Int, tileSize: CGSize)? = nil
        for rows in 1 ... count {
            let columns = Int((Double(count) / Double(rows)).rounded(.up))
            var tileWidth = (width - 2 * margin - CGFloat(columns - 1) * gap) / CGFloat(columns)
            var tileHeight = tileWidth / aspectRatio
            if CGFloat(rows) * (tileHeight + extraRowHeight) + CGFloat(rows - 1) * gap > height {
                tileHeight = (height - CGFloat(rows - 1) * gap) / CGFloat(rows) - extraRowHeight
                tileWidth = tileHeight * aspectRatio
            }
            let tileSize = CGSize(width: tileWidth.rounded(.down), height: tileHeight.rounded(.down))
            if let b = best, b.tileSize.width * b.tileSize.height >= tileSize.width * tileSize.height { continue }
            best = (rows, columns, tileSize)
        }
        return best.orDie()
    }

    /// The windows are mapped from the reference rectangle (the bounding box of the tiling windows, or the monitor if
    /// there are none) onto the tile inset by half the padding. Then every window is shrunk by half the padding on each
    /// side. The result: `padding` between the tile edge and a window, `padding` between two windows
    private static func windows(of workspace: WorkspaceSnapshot, in tile: CGRect, monitor: Rect) -> [(window: WindowSnapshot, frame: CGRect)] {
        let reference = workspace.windows.lazy.filter { $0.kind == .tiling }.compactMap { $0.frame?.cgRect }
            .reduce(nil as CGRect?) { acc, rect in acc?.union(rect) ?? rect }
            ?? monitor.cgRect
        let inner = tile.insetBy(dx: padding / 2, dy: padding / 2)
        let scaleX = inner.width / reference.width
        let scaleY = inner.height / reference.height
        return workspace.windows.compactMap { window in
            guard let rect = window.frame?.cgRect else { return nil }
            let frame = CGRect(
                x: inner.minX + (rect.minX - reference.minX) * scaleX,
                y: inner.minY + (rect.minY - reference.minY) * scaleY,
                width: rect.width * scaleX,
                height: rect.height * scaleY,
            ).insetBy(dx: padding / 2, dy: padding / 2)
            // A floating window may lie outside of the tiling windows. Keep it inside the tile, so it stays clickable
            return (window, window.kind == .floating ? frame.intersection(tile.insetBy(dx: padding, dy: padding)) : frame)
        }
    }

    func tile(at point: CGPoint) -> Tile? {
        tiles.first { $0.footprint.contains(point) }
    }

    /// The window thumbnail or chip under the point (on a tile or on the shelf)
    func window(at point: CGPoint) -> (window: WindowSnapshot, frame: CGRect)? {
        if let tile = tile(at: point) {
            return tile.chips.last { $0.frame.contains(point) } ?? tile.windows.last { $0.frame.contains(point) }
        }
        return shelfChips.first { $0.frame.contains(point) }
    }

    func frame(of window: WindowSnapshot) -> CGRect? {
        (tiles.lazy.flatMap { $0.windows + $0.chips } + shelfChips).first { $0.window == window }?.frame
    }
}

extension Rect {
    fileprivate var cgRect: CGRect { CGRect(x: topLeftX, y: topLeftY, width: width, height: height) }
}

enum DropTarget: Equatable {
    /// Move the dragged window to the workspace
    case workspace(String)
    case before(WindowSnapshot)
    case after(WindowSnapshot)
    case join(WindowSnapshot)
    /// Exchange the contents of the dragged workspace and this one
    case swap(String)

    /// Drop zones of a window thumbnail: the edges along the parent container orientation insert the dragged window
    /// before/after the target, the center joins the dragged window with the target
    static let edgeZone: CGFloat = 0.3

    init?(_ layout: CommandCenterLayout, at point: CGPoint, dragging source: DragSource) {
        guard let tile = layout.tile(at: point) else { return nil }
        switch source {
            case .workspace(let name):
                if tile.workspace.name == name { return nil }
                self = .swap(tile.workspace.name)
            case .window(let source):
                // Only windows that take part in a layout can be inserted next to another window. Chips can only land on a workspace
                guard source.isInLayout, let (target, frame) = layout.window(at: point), target != source, target.isInLayout, let orientation = target.parentOrientation else {
                    self = .workspace(tile.workspace.name)
                    return
                }
                let proportion = orientation == .h
                    ? (point.x - frame.minX) / frame.width
                    : (point.y - frame.minY) / frame.height
                self = switch proportion {
                    case ..<Self.edgeZone: .before(target)
                    case (1 - Self.edgeZone)...: .after(target)
                    default: .join(target)
                }
        }
    }
}

/// What is being dragged in the command center
enum DragSource: Equatable {
    case window(WindowSnapshot)
    /// A whole workspace tile, grabbed by its badge or its empty area
    case workspace(String)
}
