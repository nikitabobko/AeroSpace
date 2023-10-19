import XCTest
@testable import AeroSpace_Debug

final class MoveThroughCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }

    func testMove_swapWindows() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0).focus()
            TestWindow(id: 2, parent: $0)
        }

        await MoveThroughCommand(direction: .right).runWithoutRefresh()
        XCTAssertEqual(root.layoutDescription, .h_list([.window(2), .window(1)]))
    }

    func testMoveInto_findTopMostContainerWithRightOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            TestWindow(id: 1, parent: $0).focus()
            TilingContainer.newHList(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHList(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow(id: 2, parent: $0)
                }
            }
        }

        await MoveThroughCommand(direction: .right).runWithoutRefresh()
        XCTAssertEqual(
            root.layoutDescription,
            .h_list([
                .window(0),
                .h_list([
                    .window(1),
                    .h_list([
                        .window(2)
                    ])
                ])
            ])
        )
    }

    func testMove_mru() async {
        var window3: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0)
            TestWindow(id: 1, parent: $0).focus()
            TilingContainer.newVList(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHList(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow(id: 2, parent: $0)
                    window3 = TestWindow(id: 3, parent: $0)
                }
                TestWindow(id: 4, parent: $0)
            }
        }
        window3.markAsMostRecentChild()

        await MoveThroughCommand(direction: .right).runWithoutRefresh()
        XCTAssertEqual(
            root.layoutDescription,
            .h_list([
                .window(0),
                .v_list([
                    .h_list([
                        .window(1),
                        .window(2),
                        .window(3),
                    ]),
                    .window(4)
                ])
            ])
        )
    }

    func testSwap_preserveWeight() async {
        let root = Workspace.get(byName: name).rootTilingContainer
        let window1 = TestWindow(id: 1, parent: root, adaptiveWeight: 1)
        let window2 = TestWindow(id: 2, parent: root, adaptiveWeight: 2)
        window2.focus()

        await MoveThroughCommand(direction: .left).runWithoutRefresh() // todo replace all 'runWithoutRefresh' with 'run' in tests
        XCTAssertEqual(window2.hWeight, 2)
        XCTAssertEqual(window1.hWeight, 1)
    }

    func testMoveIn_newWeight() async {
        var window1: Window!
        var window2: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 0, parent: $0, adaptiveWeight: 1)
            window1 = TestWindow(id: 1, parent: $0, adaptiveWeight: 2)
            TilingContainer.newVList(parent: $0, adaptiveWeight: 1).apply {
                window2 = TestWindow(id: 2, parent: $0, adaptiveWeight: 1)
            }
        }
        window1.focus()

        await MoveThroughCommand(direction: .right).runWithoutRefresh()
        XCTAssertEqual(window2.hWeight, 1)
        XCTAssertEqual(window2.vWeight, 1)
        XCTAssertEqual(window1.vWeight, 1)
        XCTAssertEqual(window1.hWeight, 1)
    }

    func testCreateImplicitContainer() async {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TestWindow(id: 2, parent: $0).focus()
            TestWindow(id: 3, parent: $0)
        }

        await MoveThroughCommand(direction: .up).runWithoutRefresh()
        XCTAssertEqual(
            workspace.layoutDescription,
            .workspace([
                .v_list([
                    .window(2),
                    .h_list([.window(1), .window(3)])
                ])
            ])
        )
    }

    func testMoveOut() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow(id: 1, parent: $0)
            TilingContainer.newVList(parent: $0, adaptiveWeight: 1).apply {
                TestWindow(id: 2, parent: $0).focus()
                TestWindow(id: 3, parent: $0)
                TestWindow(id: 4, parent: $0)
            }
        }

        await MoveThroughCommand(direction: .left).runWithoutRefresh()
        XCTAssertEqual(
            root.layoutDescription,
            .h_list([
                .window(1),
                .window(2),
                .v_list([
                    .window(3),
                    .window(4),
                ])
            ])
        )
    }
}

extension TreeNode {
    var layoutDescription: LayoutDescription {
        switch genericKind {
        case .window(let window):
            return .window(window.windowId)
        case .tilingContainer(let container):
            switch container.layout {
            case .List:
                return container.orientation == .H
                    ? .h_list(container.children.map(\.layoutDescription))
                    : .v_list(container.children.map(\.layoutDescription))
            case .Accordion:
                return container.orientation == .H
                    ? .h_accordion(container.children.map(\.layoutDescription))
                    : .v_accordion(container.children.map(\.layoutDescription))
            }
        case .workspace:
            return .workspace(workspace.children.map(\.layoutDescription))
        }
    }
}

enum LayoutDescription: Equatable {
    case workspace([LayoutDescription])
    case h_list([LayoutDescription])
    case v_list([LayoutDescription])
    case h_accordion([LayoutDescription])
    case v_accordion([LayoutDescription])
    case window(UInt32)
}
