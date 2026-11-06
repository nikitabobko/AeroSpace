@testable import AppBundle
import AppKit
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct CommandCenterLayoutTest {
    init() { setUpWorkspacesForTests() }

    private func layout(workspaces: Int, shelf: [WindowSnapshot] = [], monitor: Rect = Rect(topLeftX: 0, topLeftY: 0, width: 2056, height: 1329)) -> CommandCenterLayout {
        var snapshots: [WorkspaceSnapshot] = []
        for i in 1 ... workspaces {
            snapshots.append(WorkspaceSnapshot(name: String(i), isFocused: i == 1, isVisible: i == 1, windows: [], chips: []))
        }
        return CommandCenterLayout(monitor: MonitorSnapshot(rect: monitor, workspaces: snapshots, shelf: shelf))
    }

    @Test func testGridIsDenseAndEvenlySpaced() {
        let layout = layout(workspaces: 6)
        let tiles = layout.tiles
        assertEquals(tiles.count, 6)
        // 3 columns x 2 rows, all tiles the same size with the monitor aspect ratio
        let size = tiles[0].frame.size
        for tile in tiles {
            assertEquals(tile.frame.size, size)
        }
        assertEquals((size.width / size.height).rounded(toPlaces: 1), (2056.0 / 1329.0).rounded(toPlaces: 1))
        assertEquals(tiles[1].frame.minX - tiles[0].frame.maxX, CommandCenterLayout.gap)
        assertEquals(tiles[2].frame.minX - tiles[1].frame.maxX, CommandCenterLayout.gap)
        // Rows are separated by the gap, measured from the tile to the badge of the tile below
        assertEquals(tiles[3].badge.minY - tiles[0].frame.maxY, CommandCenterLayout.gap)
        assertEquals(tiles[3].frame.minX, tiles[0].frame.minX)
        // The block is centered on the monitor (up to the rounding to whole points)
        assertTrue(abs(tiles[0].frame.minX - (2056 - tiles[2].frame.maxX)) <= 1)
        assertTrue(abs(tiles[0].badge.minY - (1329 - tiles[3].frame.maxY)) <= 1)
        assertTrue(tiles[0].frame.minX >= CommandCenterLayout.margin)
        assertTrue(tiles[0].badge.minY >= CommandCenterLayout.margin)
    }

    @Test func testShortLastRowIsCentered() {
        let tiles = layout(workspaces: 5).tiles
        assertEquals(tiles.count, 5)
        assertEquals(tiles[3].frame.minY, tiles[4].frame.minY)
        assertTrue(tiles[3].frame.minY > tiles[2].frame.maxY)
        let row2Center = (tiles[3].frame.minX + tiles[4].frame.maxX) / 2
        assertTrue(abs(row2Center - 2056 / 2) <= 1)
    }

    @Test func testBadgeSitsAboveTheTile() {
        let tile = layout(workspaces: 1).tiles[0]
        assertEquals(tile.badge.width, CommandCenterLayout.badgeDiameter)
        assertEquals(tile.badge.height, CommandCenterLayout.badgeDiameter)
        assertEquals(tile.frame.minY - tile.badge.maxY, CommandCenterLayout.padding)
        assertEquals(tile.badge.minX, tile.frame.minX)
        assertTrue(tile.footprint.contains(tile.badge))
    }

    @Test func testShelfTakesTheBottomAndTheGridMovesUp() {
        let withoutShelf = layout(workspaces: 6)
        assertNil(withoutShelf.shelf)
        assertTrue(withoutShelf.shelfChips.isEmpty)

        let shelf = layout(workspaces: 6, shelf: [minimizedSnapshot(id: 1), minimizedSnapshot(id: 2), minimizedSnapshot(id: 3)])
        let rect = shelf.shelf.orDie()
        assertEquals(rect.maxY, 1329 - CommandCenterLayout.margin)
        assertEquals(rect.height, CommandCenterLayout.shelfHeight)
        assertTrue(abs(rect.midX - 2056 / 2) <= 1)
        assertEquals(shelf.shelfChips.count, 3)
        assertEquals(shelf.shelfChips[0].frame.minX - rect.minX, CommandCenterLayout.padding)
        assertEquals(shelf.shelfChips[1].frame.minX - shelf.shelfChips[0].frame.maxX, CommandCenterLayout.padding)
        assertEquals(rect.maxX - shelf.shelfChips[2].frame.maxX, CommandCenterLayout.padding)
        // The grid never overlaps the shelf
        for tile in shelf.tiles {
            assertTrue(tile.frame.maxY + CommandCenterLayout.gap <= rect.minY)
        }
        assertTrue(shelf.tiles[0].frame.height <= withoutShelf.tiles[0].frame.height) // The grid only shrinks when the shelf takes its room
        // Chips are windows for hit testing
        assertEquals(shelf.window(at: CGPoint(x: shelf.shelfChips[1].frame.midX, y: shelf.shelfChips[1].frame.midY))?.window.windowId, 2)
    }

    /// A snapshot of a minimized window
    private func minimizedSnapshot(id: OpaqueWindowId) -> WindowSnapshot {
        WindowSnapshot(TestWindow.new(id: id, parent: macosMinimizedWindowsContainer), workspace: nil, frame: nil, path: nil, kind: .macosMinimized, focus: globalFocus)
    }
}

extension CGFloat {
    fileprivate func rounded(toPlaces places: Int) -> CGFloat {
        let factor = pow(10, CGFloat(places))
        return (self * factor).rounded() / factor
    }
}
