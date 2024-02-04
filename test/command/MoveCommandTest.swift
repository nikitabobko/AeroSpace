import XCTest
import Common
@testable import AeroSpace_Debug

final class MoveCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testMove_swapWindows() {
        var start: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            start = TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0)
        }
        start.focus()

        MoveCommand(args: MoveCmdArgs(.right)).run(.focused)
        XCTAssertEqual(root.layoutDescription, .h_tiles([.window(2), .window(1)]))
    }

    func testMoveInto_findTopMostContainerWithRightOrientation() {
        var start: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            start = TestWindow(id: 1, parent: $0)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow(id: 2, parent: $0)
                }
            }
        }
        start.focus()

        MoveCommand(args: MoveCmdArgs(.right)).run(.focused)
        XCTAssertEqual(
            root.layoutDescription,
            .h_tiles([
                .window(0),
                .h_tiles([
                    .window(1),
                    .h_tiles([
                        .window(2)
                    ])
                ])
            ])
        )
    }

    func testMove_mru() {
        var window3: Window!
        var start: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            start = TestWindow(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow(id: 2, parent: $0)
                    window3 = TestWindow(id: 3, parent: $0)
                }
                TestWindow(id: 4, parent: $0)
            }
        }
        window3.markAsMostRecentChild()
        start.focus()

        MoveCommand(args: MoveCmdArgs(.right)).run(.focused)
        XCTAssertEqual(
            root.layoutDescription,
            .h_tiles([
                .window(0),
                .v_tiles([
                    .h_tiles([
                        .window(1),
                        .window(2),
                        .window(3),
                    ]),
                    .window(4)
                ])
            ])
        )
    }

    func testSwap_preserveWeight() {
        let root = Workspace.get(byName: name).rootTilingContainer
        let window1 = TestWindow(id: 1, parent: root, adaptiveWeight: 1)
        let window2 = TestWindow(id: 2, parent: root, adaptiveWeight: 2)
        window2.focus()

        MoveCommand(args: MoveCmdArgs(.left)).run(.focused)
        XCTAssertEqual(window2.hWeight, 2)
        XCTAssertEqual(window1.hWeight, 1)
    }

    func testMoveIn_newWeight() {
        var window1: Window!
        var window2: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0, adaptiveWeight: 1)
            window1 = TestWindow(id: 1, parent: $0, adaptiveWeight: 2)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                window2 = TestWindow(id: 2, parent: $0, adaptiveWeight: 1)
            }
        }
        window1.focus()

        MoveCommand(args: MoveCmdArgs(.right)).run(.focused)
        XCTAssertEqual(window2.hWeight, 1)
        XCTAssertEqual(window2.vWeight, 1)
        XCTAssertEqual(window1.vWeight, 1)
        XCTAssertEqual(window1.hWeight, 1)
    }

    func testCreateImplicitContainer() {
        let workspace = Workspace.get(byName: name)
        var start: Window!
        workspace.rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            start = TestWindow(id: 2, parent: $0)
            TestWindow(id: 3, parent: $0)
        }
        start.focus()

        MoveCommand(args: MoveCmdArgs(.up)).run(.focused)
        XCTAssertEqual(
            workspace.layoutDescription,
            .workspace([
                .v_tiles([
                    .window(2),
                    .h_tiles([.window(1), .window(3)])
                ])
            ])
        )
    }

    func testMoveOut() {
        var start: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                start = TestWindow(id: 2, parent: $0)
                TestWindow(id: 3, parent: $0)
                TestWindow(id: 4, parent: $0)
            }
        }
        start.focus()

        MoveCommand(args: MoveCmdArgs(.left)).run(.focused)
        XCTAssertEqual(
            root.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
                .v_tiles([
                    .window(3),
                    .window(4),
                ])
            ])
        )
    }

    func testMoveOutWithNormalization_right() {
        config.enableNormalizationFlattenContainers = true

        var start: Window!
        let workspace = Workspace.get(byName: name).apply {
            TestWindow(id: 1, parent: $0.rootTilingContainer)
            start = TestWindow(id: 2, parent: $0.rootTilingContainer)
        }
        start.focus()

        MoveCommand(args: MoveCmdArgs(.right)).run(.focused)
        XCTAssertEqual(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
            ])
        )
        XCTAssertEqual(focusedWindow?.windowId, 2)
    }

    func testMoveOutWithNormalization_left() {
        config.enableNormalizationFlattenContainers = true

        var start: Window!
        let workspace = Workspace.get(byName: name).apply {
            start = TestWindow(id: 1, parent: $0.rootTilingContainer)
            TestWindow(id: 2, parent: $0.rootTilingContainer)
        }
        start.focus()

        MoveCommand(args: MoveCmdArgs(.left)).run(.focused)
        XCTAssertEqual(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
            ])
        )
        XCTAssertEqual(focusedWindow?.windowId, 1)
    }
}

extension TreeNode {
    var layoutDescription: LayoutDescription {
        switch nodeCases {
        case .window(let window):
            return .window(window.windowId)
        case .tilingContainer(let container):
            switch container.layout {
            case .tiles:
                return container.orientation == .h
                    ? .h_tiles(container.children.map(\.layoutDescription))
                    : .v_tiles(container.children.map(\.layoutDescription))
            case .accordion:
                return container.orientation == .h
                    ? .h_accordion(container.children.map(\.layoutDescription))
                    : .v_accordion(container.children.map(\.layoutDescription))
            }
        case .workspace:
            return .workspace(workspace.children.map(\.layoutDescription))
        case .macosInvisibleWindowsContainer:
            return .macosInvisible
        }
    }
}

enum LayoutDescription: Equatable {
    case workspace([LayoutDescription])
    case h_tiles([LayoutDescription])
    case v_tiles([LayoutDescription])
    case h_accordion([LayoutDescription])
    case v_accordion([LayoutDescription])
    case window(UInt32)
    case macosInvisible
}
