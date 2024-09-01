import XCTest
import Common
@testable import AppBundle

final class MoveCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testMove_swapWindows() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow(id: 1, parent: $0).focusWindow(), true)
            TestWindow(id: 2, parent: $0)
        }

        MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.focused)
        assertEquals(root.layoutDescription, .h_tiles([.window(2), .window(1)]))
    }

    func testMoveInto_findTopMostContainerWithRightOrientation() {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            assertEquals(TestWindow(id: 1, parent: $0).focusWindow(), true)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow(id: 2, parent: $0)
                }
            }
        }

        MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.focused)
        assertEquals(
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
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            assertEquals(TestWindow(id: 1, parent: $0).focusWindow(), true)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow(id: 2, parent: $0)
                    window3 = TestWindow(id: 3, parent: $0)
                }
                TestWindow(id: 4, parent: $0)
            }
        }
        window3.markAsMostRecentChild()

        MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.focused)
        assertEquals(
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
        _ = window2.focusWindow()

        MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.focused)
        assertEquals(window2.hWeight, 2)
        assertEquals(window1.hWeight, 1)
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
        _ = window1.focusWindow()

        MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.focused)
        assertEquals(window2.hWeight, 1)
        assertEquals(window2.vWeight, 1)
        assertEquals(window1.vWeight, 1)
        assertEquals(window1.hWeight, 1)
    }

    func testCreateImplicitContainer() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            assertEquals(TestWindow(id: 2, parent: $0).focusWindow(), true)
            TestWindow(id: 3, parent: $0)
        }

        MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.focused)
        assertEquals(
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
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow(id: 2, parent: $0).focusWindow(), true)
                TestWindow(id: 3, parent: $0)
                TestWindow(id: 4, parent: $0)
            }
        }

        MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.focused)
        assertEquals(
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

        let workspace = Workspace.get(byName: name).apply {
            TestWindow(id: 1, parent: $0.rootTilingContainer)
            assertEquals(TestWindow(id: 2, parent: $0.rootTilingContainer).focusWindow(), true)
        }

        MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.focused)
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
            ])
        )
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testMoveOutWithNormalization_left() {
        config.enableNormalizationFlattenContainers = true

        let workspace = Workspace.get(byName: name).apply {
            assertEquals(TestWindow(id: 1, parent: $0.rootTilingContainer).focusWindow(), true)
            TestWindow(id: 2, parent: $0.rootTilingContainer)
        }

        MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.focused)
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
            ])
        )
        assertEquals(focus.windowOrNil?.windowId, 1)
    }
}

extension TreeNode {
    var layoutDescription: LayoutDescription {
        return switch nodeCases {
            case .window(let window): .window(window.windowId)
            case .workspace(let workspace): .workspace(workspace.children.map(\.layoutDescription))
            case .macosMinimizedWindowsContainer: .macosInvisible
            case .macosFullscreenWindowsContainer: .macosFullscreen
            case .macosPopupWindowsContainer: .macosPopupWindowsContainer
            case .tilingContainer(let container):
                switch container.layout {
                    case .tiles:
                        container.orientation == .h
                            ? .h_tiles(container.children.map(\.layoutDescription))
                            : .v_tiles(container.children.map(\.layoutDescription))
                    case .accordion:
                        container.orientation == .h
                            ? .h_accordion(container.children.map(\.layoutDescription))
                            : .v_accordion(container.children.map(\.layoutDescription))
                }
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
    case macosPopupWindowsContainer
    case macosInvisible
    case macosFullscreen
}
