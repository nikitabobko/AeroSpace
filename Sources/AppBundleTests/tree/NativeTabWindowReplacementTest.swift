@testable import AppBundle
import XCTest

@MainActor
final class NativeTabWindowReplacementTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testReplacementPreservesNestedTreeSlotAndWeight() throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        let container = TilingContainer.newHTiles(parent: root, adaptiveWeight: 1)
        TestWindow.new(id: 1, parent: container)
        let oldWindow = TestWindow.new(id: 2, parent: container, adaptiveWeight: 3)
        TestWindow.new(id: 3, parent: container)

        let replacement = takeNativeTabReplacementBinding(
            from: [oldWindow],
            lastFocusedWindowId: nil,
        )
        let bindingData = try XCTUnwrap(replacement).bindingData
        let newWindow = TestWindow.new(id: 4, parent: root)
        newWindow.bind(
            to: bindingData.parent,
            adaptiveWeight: bindingData.adaptiveWeight,
            index: bindingData.index,
        )

        assertEquals(container.layoutDescription, .h_tiles([.window(1), .window(4), .window(3)]))
        assertEquals(newWindow.getWeight(.h), 3)
    }

    func testReplacementPrefersLastFocusedWindow() {
        let root = Workspace.get(byName: name).rootTilingContainer
        let first = TestWindow.new(id: 1, parent: root)
        let lastFocused = TestWindow.new(id: 2, parent: root)

        let replacement = takeNativeTabReplacementBinding(
            from: [first, lastFocused],
            lastFocusedWindowId: lastFocused.windowId,
        )

        assertEquals(replacement?.window.windowId, lastFocused.windowId)
        XCTAssertTrue(first.isBound)
        XCTAssertFalse(lastFocused.isBound)
    }

    func testReplacementDoesNotGuessWhenStaleWindowsAreAmbiguous() {
        let root = Workspace.get(byName: name).rootTilingContainer
        let first = TestWindow.new(id: 1, parent: root)
        let second = TestWindow.new(id: 2, parent: root)

        let replacement = takeNativeTabReplacementBinding(
            from: [first, second],
            lastFocusedWindowId: nil,
        )

        XCTAssertNil(replacement)
        XCTAssertTrue(first.isBound)
        XCTAssertTrue(second.isBound)
    }

    func testAffectedBundleIds() {
        XCTAssertTrue(KnownBundleId.ghostty.exposesInactiveNativeTabsAsWindows)
        XCTAssertTrue(KnownBundleId.fork.exposesInactiveNativeTabsAsWindows)
        XCTAssertFalse(KnownBundleId.iterm2.exposesInactiveNativeTabsAsWindows)
    }
}
