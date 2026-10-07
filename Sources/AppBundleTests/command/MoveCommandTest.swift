@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertNil(parseCommand("move --fail-if-fullscreen left").errorOrNil)
        assertNil(parseCommand("move --fail-if-macos-native-fullscreen --window-id 1 right").errorOrNil)
        assertNil(parseCommand("move --boundaries all-monitors-outer-frame --boundaries-action wrap-around-all-monitors right").errorOrNil)
        assertEquals(
            parseCommand("move --boundaries-action wrap-around-all-monitors right").errorOrNil,
            "workspace and wrap-around-all-monitors is an invalid combination of values",
        )
    }

    func testWrapAroundAllMonitors_onSingleMonitor() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            assertEquals(TestWindow.new(id: 3, parent: $0).focusWindow(), true)
        }

        let command = "move --boundaries all-monitors-outer-frame --boundaries-action wrap-around-all-monitors"
        var result = await parseCommand("\(command) right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layoutDescription, .h_tiles([.window(3), .window(1), .window(2)]))
        assertEquals(focus.windowOrNil?.windowId, 3)

        result = await parseCommand("\(command) left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2), .window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 3)
    }

    func testWrapAroundAllMonitors_onSingleMonitorWithOppositeRootOrientation() async {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand(
            "move --boundaries all-monitors-outer-frame --boundaries-action wrap-around-all-monitors up",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .v_tiles([
                    .h_tiles([.window(2)]),
                    .window(1),
                ]),
            ]),
        )
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testWrapAroundAllMonitors_acrossTwoMonitors() async {
        let (leftMonitor, rightMonitor) = useTwoTestMonitors()
        let leftWorkspace = Workspace.get(byName: "left")
        let rightWorkspace = Workspace.get(byName: "right")
        assertEquals(leftMonitor.setActiveWorkspace(leftWorkspace), true)
        assertEquals(rightMonitor.setActiveWorkspace(rightWorkspace), true)

        leftWorkspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
        }
        rightWorkspace.rootTilingContainer.apply {
            TestWindow.new(id: 3, parent: $0)
            assertEquals(TestWindow.new(id: 4, parent: $0).focusWindow(), true)
        }

        let result = await parseCommand(
            "move --boundaries all-monitors-outer-frame --boundaries-action wrap-around-all-monitors right",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(leftWorkspace.rootTilingContainer.layoutDescription, .h_tiles([.window(4), .window(1), .window(2)]))
        assertEquals(rightWorkspace.rootTilingContainer.layoutDescription, .h_tiles([.window(3)]))
        assertEquals(focus.windowOrNil?.windowId, 4)
        assertEquals(focus.workspace, leftWorkspace)

        let reverseResult = await parseCommand(
            "move --boundaries all-monitors-outer-frame --boundaries-action wrap-around-all-monitors left",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(reverseResult.exitCode.rawValue, 0)
        assertEquals(leftWorkspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .window(2)]))
        assertEquals(rightWorkspace.rootTilingContainer.layoutDescription, .h_tiles([.window(3), .window(4)]))
        assertEquals(focus.windowOrNil?.windowId, 4)
        assertEquals(focus.workspace, rightWorkspace)
    }

    func testWrapAroundAllMonitors_usesSameMonitorAsFocus() async {
        for orientation in [Orientation.h, .v] {
            let positive: CardinalDirection = orientation == .h ? .right : .down
            let negative: CardinalDirection = orientation == .h ? .left : .up
            for (direction, sourceIndex, expectedIndex) in [(positive, 2, 0), (negative, 0, 2), (positive, 1, 2), (negative, 1, 0)] {
                setUpWorkspacesForTests()
                config.defaultRootContainerOrientation = orientation == .h ? .horizontal : .vertical
                let monitors = useTestMonitors((0 ..< 3).map { index in
                    Rect(
                        topLeftX: orientation == .h ? CGFloat(index) * 1920 : 0,
                        topLeftY: orientation == .v ? CGFloat(index) * 1080 : 0,
                        width: 1920,
                        height: 1080,
                    )
                })
                let workspaces = monitors.enumerated().map { index, monitor in
                    let workspace = Workspace.get(byName: "monitor-\(index)")
                    assertEquals(monitor.setActiveWorkspace(workspace), true)
                    return workspace
                }
                let windows = workspaces.enumerated().map { index, workspace in
                    TestWindow.new(id: UInt32(index + 1), parent: workspace.rootTilingContainer)
                }
                let sourceWindow = windows[sourceIndex]
                assertEquals(sourceWindow.focusWindow(), true)

                let options = "--boundaries all-monitors-outer-frame --boundaries-action wrap-around-all-monitors \(direction.rawValue)"
                let focusResult = await parseCommand("focus \(options)").cmdOrDie.run(.defaultEnv, .emptyStdin)
                assertEquals(focusResult.exitCode.rawValue, 0)
                let focusWorkspace = focus.workspace
                assertEquals(focusWorkspace, workspaces[expectedIndex])

                assertEquals(sourceWindow.focusWindow(), true)
                let moveResult = await parseCommand("move \(options)").cmdOrDie.run(.defaultEnv, .emptyStdin)
                assertEquals(moveResult.exitCode.rawValue, 0)
                assertEquals(sourceWindow.nodeWorkspace, focusWorkspace)
                assertEquals(focus.workspace, focusWorkspace)
                assertEquals(focus.windowOrNil?.windowId, sourceWindow.windowId)
            }
        }
    }

    func testWrapAroundAllMonitors_doesNotStealFocusForExplicitWindow() async {
        let (leftMonitor, rightMonitor) = useTwoTestMonitors()
        let leftWorkspace = Workspace.get(byName: "left")
        let rightWorkspace = Workspace.get(byName: "right")
        assertEquals(leftMonitor.setActiveWorkspace(leftWorkspace), true)
        assertEquals(rightMonitor.setActiveWorkspace(rightWorkspace), true)

        leftWorkspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
        }
        TestWindow.new(id: 2, parent: rightWorkspace.rootTilingContainer)

        let result = await parseCommand(
            "move --window-id 2 --boundaries all-monitors-outer-frame --boundaries-action wrap-around-all-monitors right",
        ).cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(leftWorkspace.rootTilingContainer.layoutDescription, .h_tiles([.window(2), .window(1)]))
        assertEquals(rightWorkspace.rootTilingContainer.layoutDescription, .h_tiles([]))
        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.workspace, leftWorkspace)
    }

    func testFailIfFullscreen() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            let window = TestWindow.new(id: 1, parent: $0)
            assertEquals(window.focusWindow(), true)
            window.isFullscreen = true
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("move --fail-if-fullscreen right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }

    func testFailIfMacosNativeFullscreen() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            let window = TestWindow.new(id: 1, parent: $0)
            assertEquals(window.focusWindow(), true)
            window.isMacosFullscreenForTest = true
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("move --fail-if-macos-native-fullscreen right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(root.layoutDescription, .h_tiles([.window(1), .window(2)]))
    }

    func testFailIfFullscreenAllowsRegularWindows() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = await parseCommand("move --fail-if-fullscreen --fail-if-macos-native-fullscreen right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(root.layoutDescription, .h_tiles([.window(2), .window(1)]))
    }

    func testMove_swapWindows() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        await parseCommand("move right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.window(2), .window(1)]))
    }

    func testMoveInto_findTopMostContainerWithRightOrientation() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0)
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                }
            }
        }

        await parseCommand("move right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            root.layoutDescription,
            .h_tiles([
                .window(0),
                .h_tiles([
                    .window(1),
                    .h_tiles([
                        .window(2),
                    ]),
                ]),
            ]),
        )
    }

    func testMove_mru() async {
        var window3: Window!
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0)
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 2, parent: $0)
                    window3 = TestWindow.new(id: 3, parent: $0)
                }
                TestWindow.new(id: 4, parent: $0)
            }
        }
        window3.markAsMostRecentChild()

        await parseCommand("move right").cmdOrDie.run(.defaultEnv, .emptyStdin)
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
                    .window(4),
                ]),
            ]),
        )
    }

    func testSwap_preserveWeight() async {
        let root = Workspace.get(byName: name).rootTilingContainer
        let window1 = TestWindow.new(id: 1, parent: root, adaptiveWeight: 1)
        let window2 = TestWindow.new(id: 2, parent: root, adaptiveWeight: 2)
        _ = window2.focusWindow()

        await parseCommand("move left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window2.hWeight, 2)
        assertEquals(window1.hWeight, 1)
    }

    func testMoveIn_newWeight() async {
        var window1: Window!
        var window2: Window!
        Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0, adaptiveWeight: 1)
            window1 = TestWindow.new(id: 1, parent: $0, adaptiveWeight: 2)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                window2 = TestWindow.new(id: 2, parent: $0, adaptiveWeight: 1)
            }
        }
        _ = window1.focusWindow()

        await parseCommand("move right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window2.hWeight, 1)
        assertEquals(window2.vWeight, 1)
        assertEquals(window1.vWeight, 1)
        assertEquals(window1.hWeight, 1)
    }

    func testCreateImplicitContainer() async {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }

        let result = await parseCommand("move up").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .v_tiles([
                    .window(2),
                    .h_tiles([.window(1), .window(3)]),
                ]),
            ]),
        )
        assertEquals(result.exitCode.rawValue, 0)
    }

    func testStop_onRootNode() async {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        let result = await parseCommand("move --boundaries-action stop left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .h_tiles([.window(1), .window(2), .window(3)]),
            ]),
        )
        assertEquals(result.exitCode.rawValue, 0)
    }

    func testStop_onRootNode_withOppositeOrientation() async {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        let result = await parseCommand("move --boundaries-action stop up").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .h_tiles([.window(1), .window(2), .window(3)]),
            ]),
        )
        assertEquals(result.exitCode.rawValue, 0)
    }

    func testStop_onRootNode_whenNoBoundary() async {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
            TestWindow.new(id: 3, parent: $0)
        }

        let result = await parseCommand("move --boundaries-action stop left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .h_tiles([.window(2), .window(1), .window(3)]),
            ]),
        )
        assertEquals(result.exitCode.rawValue, 0)
    }

    func testStop_onInnerNode() async {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
                TestWindow.new(id: 3, parent: $0)
            }
        }

        let result = await parseCommand("move --boundaries-action stop right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .h_tiles([.window(1), .v_tiles([.window(3)]), .window(2)]),
            ]),
        )
        assertEquals(result.exitCode.rawValue, 0)
    }

    func testFail() async {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        let result = await parseCommand("move --boundaries-action fail left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.layoutDescription,
            .workspace([
                .h_tiles([.window(1), .window(2), .window(3)]),
            ]),
        )
        assertEquals(result.exitCode.rawValue, 2)
    }

    func testMoveOut() async {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                assertEquals(TestWindow.new(id: 2, parent: $0).focusWindow(), true)
                TestWindow.new(id: 3, parent: $0)
                TestWindow.new(id: 4, parent: $0)
            }
        }

        await parseCommand("move left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            root.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
                .v_tiles([
                    .window(3),
                    .window(4),
                ]),
            ]),
        )
    }

    func testMoveOutWithNormalization_right() async {
        config.enableNormalizationFlattenContainers = true

        let workspace = Workspace.get(byName: name).apply {
            TestWindow.new(id: 1, parent: $0.rootTilingContainer)
            assertEquals(TestWindow.new(id: 2, parent: $0.rootTilingContainer).focusWindow(), true)
        }

        await parseCommand("move right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
            ]),
        )
        assertEquals(focus.windowOrNil?.windowId, 2)
    }

    func testMoveOutWithNormalization_left() async {
        config.enableNormalizationFlattenContainers = true

        let workspace = Workspace.get(byName: name).apply {
            assertEquals(TestWindow.new(id: 1, parent: $0.rootTilingContainer).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0.rootTilingContainer)
        }

        await parseCommand("move left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
            ]),
        )
        assertEquals(focus.windowOrNil?.windowId, 1)
    }
}

private struct MoveCommandTestMonitorInfo: MonitorInfo {
    let monitorAppKitNsScreenScreensId: Int
    let name: String
    let rect: Rect
    let visibleRect: Rect
    let isMain: Bool
    var width: CGFloat { rect.width }
    var height: CGFloat { rect.height }
}

private func useTwoTestMonitors() -> (left: MonitorInfo, right: MonitorInfo) {
    let monitors = useTestMonitors([
        Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
        Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
    ])
    return (monitors[0], monitors[1])
}

private func useTestMonitors(_ rects: [Rect]) -> [MonitorInfo] {
    let monitors = rects.enumerated().map { index, rect in
        MoveCommandTestMonitorInfo(
            monitorAppKitNsScreenScreensId: index + 1,
            name: "Test Monitor \(index + 1)",
            rect: rect,
            visibleRect: rect,
            isMain: index == 0,
        )
    }
    monitorInfosForTests = monitors
    return monitors
}

extension TreeNode {
    var layoutDescription: LayoutDescription {
        return switch nodeCases {
            case .window(let window): .window(window.windowId)
            case .workspace(let workspace): .workspace(workspace.children.map(\.layoutDescription))
            case .floatingWindowsContainer(let container): .floatingWindowsContainer(container.children.map(\.layoutDescription))
            case .macosMinimizedWindowsContainer: .macosMinimized
            case .macosFullscreenWindowsContainer: .macosFullscreen
            case .macosHiddenAppsWindowsContainer: .macosHiddeAppWindow
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
    case floatingWindowsContainer([LayoutDescription])
    case window(UInt32)
    case macosPopupWindowsContainer
    case macosMinimized
    case macosHiddeAppWindow
    case macosFullscreen
}
