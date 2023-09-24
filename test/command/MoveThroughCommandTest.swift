import XCTest
@testable import AeroSpace_Debug

final class MoveThroughCommandTest: XCTestCase {
    override func setUpWithError() throws { setUpWorkspacesForTests() }
    override func tearDownWithError() throws { tearDownWorkspacesForTests() }

    func testMove() async {
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

    //func testCreateImplicitContainer() async {
    //    let root = Workspace.get(byName: name).rootTilingContainer.apply {
    //        TestWindow(id: 1, parent: $0).focus()
    //        TestWindow(id: 2, parent: $0)
    //        TestWindow(id: 3, parent: $0)
    //    }
    //
    //    await MoveThroughCommand(direction: .up).runWithoutRefresh()
    //    XCTAssertEqual(
    //        root.layoutDescription,
    //        .v_list([
    //            .window(1),
    //            .h_list([.window(2), .window(3)])
    //        ])
    //    )
    //}
}

extension TreeNode {
    var layoutDescription: LayoutDescription {
        if let window = self as? Window {
            return .window(window.windowId)
        } else if let container = self as? TilingContainer {
            switch container.layout {
            case .List:
                switch container.orientation {
                case .H:
                    return .h_list(container.children.map { $0.layoutDescription })
                case .V:
                    return .v_list(container.children.map { $0.layoutDescription })
                }
            case .Accordion:
                switch container.orientation {
                case .H:
                    return .h_accordion(container.children.map { $0.layoutDescription })
                case .V:
                    return .v_accordion(container.children.map { $0.layoutDescription })
                }
            }
        } else if let workspace = self as? Workspace {
            return .workspace(workspace.children.map { $0.layoutDescription })
        } else {
            error("Unknown type: \(Self.self)")
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
