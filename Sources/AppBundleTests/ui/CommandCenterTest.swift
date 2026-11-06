@testable import AppBundle
import AppKit
import Common
import Testing

@MainActor
@Suite(.serializedGlobally)
struct CommandCenterTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse() {
        assertNil(parseCommand("command-center").errorOrNil)
        assertEquals(parseCommand("command-center --foo").errorOrNil, "ERROR: Unknown flag '--foo'")
        assertEquals(parseCommand("command-center foo").errorOrNil, "ERROR: Unknown argument 'foo'")
    }

    @Test func testSnapshot() async throws {
        let a = Workspace.get(byName: "a")
        a.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
            }
        }
        TestWindow.new(id: 4, parent: a.floatingWindowsContainer, rect: Rect(topLeftX: 10, topLeftY: 20, width: 30, height: 40))
        TestWindow.new(id: 5, parent: Workspace.get(byName: "b").rootTilingContainer)

        let snapshot = try await CommandCenterSnapshot.capture(.nonCancellable)
        assertEquals(snapshot.monitors.count, 1)
        let workspaces = snapshot.monitors[0].workspaces
        assertEquals(workspaces.map(\.name), ["a", "b", "setUpWorkspacesForTests"])
        assertEquals(workspaces.map(\.isFocused), [true, false, false])
        let windows = workspaces[0].windows
        assertEquals(windows.map(\.windowId), [1, 2, 3, 4])
        assertEquals(windows.map { $0.path?.description }, ["/0", "/1/0", "/1/1", nil])
        assertEquals(windows.map(\.parentOrientation), [.h, .v, .v, nil])
        assertEquals(windows.map(\.isFocused), [true, false, false, false])
        assertEquals(windows[3].frame?.topLeftX, 10)
        assertEquals(windows[1].parentPath?.description, "/1")
        assertEquals(windows[1].indexInParent, 0)
    }

    @Test func testAccordionWindowsAreSpreadOut() async throws {
        let a = Workspace.get(byName: "a")
        a.rootTilingContainer.layout = .accordion
        a.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }
        let snapshot = try await CommandCenterSnapshot.capture(.nonCancellable)
        let windows = snapshot.monitors[0].workspaces[0].windows
        assertEquals(windows.count, 3)
        let frames = windows.compactMap(\.frame)
        // Side by side, no overlap, same width, filling the container from left to right
        assertEquals(frames[0].width, frames[1].width)
        assertEquals(frames[1].width, frames[2].width)
        assertEquals(frames[1].topLeftX, frames[0].topLeftX + frames[0].width)
        assertEquals(frames[2].topLeftX, frames[1].topLeftX + frames[1].width)
        assertEquals(frames[0].topLeftY, frames[2].topLeftY)
    }

    @Test func testLayoutAndDropTargets() async throws {
        let a = Workspace.get(byName: "a")
        a.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
        }
        TestWindow.new(id: 3, parent: Workspace.get(byName: "b").rootTilingContainer)
        let snapshot = try await CommandCenterSnapshot.capture(.nonCancellable)
        let monitor = snapshot.monitors[0]
        let layout = CommandCenterLayout(monitor: monitor)
        assertEquals(layout.tiles.map(\.workspace.name), ["a", "b", "setUpWorkspacesForTests"])

        // Tiles don't overlap and fit the monitor
        let monitorBounds = CGRect(x: 0, y: 0, width: monitor.rect.width, height: monitor.rect.height)
        for (i, tile) in layout.tiles.enumerated() {
            assertTrue(monitorBounds.contains(tile.frame))
            for other in layout.tiles.dropFirst(i + 1) {
                assertFalse(tile.frame.intersects(other.frame))
            }
            for (_, frame) in tile.windows {
                assertTrue(tile.frame.contains(frame))
            }
        }

        let tileA = layout.tiles[0]
        let (w1, frame1) = tileA.windows[0]
        let (w2, frame2) = tileA.windows[1]
        assertEquals(frame1.width, frame2.width)
        assertEquals(frame2.minX, frame1.maxX + CommandCenterLayout.padding)
        // Tile edge to window and window to window: the same padding
        assertEquals(frame1.minX - tileA.frame.minX, CommandCenterLayout.padding)
        assertEquals(frame1.minY - tileA.frame.minY, CommandCenterLayout.padding)
        assertEquals(tileA.frame.maxX - frame2.maxX, CommandCenterLayout.padding)
        assertEquals(tileA.frame.maxY - frame1.maxY, CommandCenterLayout.padding)

        // Dragging window 2: the left edge of window 1 inserts before, the center joins, the right edge inserts after
        assertEquals(DropTarget(layout, at: CGPoint(x: frame1.minX + 1, y: frame1.midY), dragging: .window(w2)), .before(w1))
        assertEquals(DropTarget(layout, at: CGPoint(x: frame1.midX, y: frame1.midY), dragging: .window(w2)), .join(w1))
        assertEquals(DropTarget(layout, at: CGPoint(x: frame1.maxX - 1, y: frame1.midY), dragging: .window(w2)), .after(w1))
        // Dropping onto itself targets the workspace
        assertEquals(DropTarget(layout, at: CGPoint(x: frame2.midX, y: frame2.midY), dragging: .window(w2)), .workspace("a"))
        // The padding of a tile and its badge target the workspace
        let tileB = layout.tiles[1]
        assertEquals(DropTarget(layout, at: CGPoint(x: tileB.frame.midX, y: tileB.frame.minY + 2), dragging: .window(w2)), .workspace("b"))
        assertEquals(DropTarget(layout, at: CGPoint(x: tileB.badge.midX, y: tileB.badge.minY + 2), dragging: .window(w2)), .workspace("b"))
        // Dragging a tile: another tile swaps, the tile itself and the void are no target
        assertEquals(DropTarget(layout, at: CGPoint(x: tileB.frame.midX, y: tileB.frame.midY), dragging: .workspace("a")), .swap("b"))
        assertNil(DropTarget(layout, at: CGPoint(x: tileA.frame.midX, y: tileA.frame.midY), dragging: .workspace("a")))
        assertNil(DropTarget(layout, at: CGPoint(x: 1, y: 1), dragging: .workspace("a")))
        // Outside of tiles there is no target
        assertNil(DropTarget(layout, at: CGPoint(x: 1, y: 1), dragging: .window(w2)))
    }
}
