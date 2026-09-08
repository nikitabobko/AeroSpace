@testable import AppBundle
import XCTest

@MainActor
final class SmoothWorkspaceLayoutTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testDwindleSequencesFromOneThroughTenWindows() {
        for count in 1 ... 10 {
            setUpWorkspacesForTests()
            enableStyle(.dwindle)

            let root = Workspace.get(byName: name).rootTilingContainer
            let windows = (1 ... count).map { TestWindow.new(id: UInt32($0), parent: root) }

            reconcileSmoothWorkspaceLayouts()

            assertEquals(root.layoutDescription, expectedDwindle(Array(1 ... UInt32(count)), orientationIsHorizontal: true))
            assertEquals(windows[0].isFullscreen, count == 1)
            assertTrue(windows.dropFirst().allSatisfy { !$0.isFullscreen })
        }
    }

    func testVerticalPairSequencesFromOneThroughTenWindows() {
        for count in 1 ... 10 {
            setUpWorkspacesForTests()
            enableStyle(.verticalPairs)

            let root = Workspace.get(byName: name).rootTilingContainer
            let windows = (1 ... count).map { TestWindow.new(id: UInt32($0), parent: root) }

            reconcileSmoothWorkspaceLayouts()

            assertEquals(
                root.layoutDescription,
                count == 1
                    ? .h_tiles([.window(1)])
                    : expectedVerticalPairs(Array(1 ... UInt32(count))),
            )
            assertEquals(windows[0].isFullscreen, count == 1)
        }
    }

    func testNewWindowIsAppendedToDwindleTail() {
        enableStyle(.dwindle)
        let root = Workspace.get(byName: name).rootTilingContainer
        let windows = (1 ... 4).map { TestWindow.new(id: UInt32($0), parent: root) }
        reconcileSmoothWorkspaceLayouts()

        let newWindow = TestWindow.new(id: 5, parent: root)
        newWindow.bind(
            to: windows[1].parent.orDie(),
            adaptiveWeight: WEIGHT_AUTO,
            index: windows[1].ownIndex.orDie() + 1,
        )
        reconcileSmoothWorkspaceLayouts()

        assertEquals(
            root.layoutDescription,
            expectedDwindle([1, 2, 3, 4, 5], orientationIsHorizontal: true),
        )
    }

    func testClosingWindowRebuildsDwindleWithSurvivingOrder() {
        enableStyle(.dwindle)
        let root = Workspace.get(byName: name).rootTilingContainer
        let windows = (1 ... 5).map { TestWindow.new(id: UInt32($0), parent: root) }
        reconcileSmoothWorkspaceLayouts()

        windows[1].unbindFromParent()
        reconcileSmoothWorkspaceLayouts()

        assertEquals(
            root.layoutDescription,
            expectedDwindle([1, 3, 4, 5], orientationIsHorizontal: true),
        )
    }

    func testFinderTabReplacementKeepsManualSizeAndParent() {
        enableStyle(.dwindle)
        let root = Workspace.get(byName: name).rootTilingContainer
        let windows = (1 ... 4).map { TestWindow.new(id: UInt32($0), parent: root) }
        reconcileSmoothWorkspaceLayouts()
        windows[0].setWeight(.h, 71)
        let binding = windows[0].unbindFromParent()
        let replacement = TestWindow.new(id: 10, parent: binding.parent, adaptiveWeight: binding.adaptiveWeight)
        replacement.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: binding.index)
        replaceSmoothLayoutWindowId(1, with: 10)
        let shape = root.layoutDescription
        reconcileSmoothWorkspaceLayouts()
        assertEquals(root.layoutDescription, shape)
        assertTrue(replacement.parent === binding.parent)
        assertEquals(replacement.getWeight(.h), 71)
    }

    func testSameMembershipRebuildsMalformedTree() {
        enableStyle(.dwindle)
        let root = Workspace.get(byName: name).rootTilingContainer
        let windows = (1 ... 4).map { TestWindow.new(id: UInt32($0), parent: root) }
        reconcileSmoothWorkspaceLayouts()

        windows[0].bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        reconcileSmoothWorkspaceLayouts()

        assertEquals(
            root.layoutDescription,
            expectedDwindle([1, 2, 3, 4], orientationIsHorizontal: true),
        )
    }

    func testExplicitManualTreeEditIsPreservedUntilWindowMembershipChanges() {
        enableStyle(.dwindle)
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let windows = (1 ... 4).map { TestWindow.new(id: UInt32($0), parent: root) }
        reconcileSmoothWorkspaceLayouts()

        windows[0].bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        let manuallyEditedTree = root.layoutDescription
        preserveCurrentSmoothWorkspaceTreeAfterUserCommand(workspace)
        reconcileSmoothWorkspaceLayouts()

        assertEquals(root.layoutDescription, manuallyEditedTree)

        TestWindow.new(id: 5, parent: root)
        reconcileSmoothWorkspaceLayouts()
        assertEquals(
            root.layoutDescription,
            expectedDwindle([2, 3, 4, 1, 5], orientationIsHorizontal: true),
        )
    }

    func testExplicitManualTreeEditSurvivesNormalizationBeforeReconcile() {
        enableStyle(.dwindle)
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let windows = (1 ... 4).map { TestWindow.new(id: UInt32($0), parent: root) }
        reconcileSmoothWorkspaceLayouts()

        let tail = root.children[1]
        let previousBinding = tail.unbindFromParent()
        let joined = TilingContainer(
            parent: root,
            adaptiveWeight: previousBinding.adaptiveWeight,
            .v,
            .tiles,
            index: previousBinding.index,
        )
        windows[0].unbindFromParent()
        tail.bind(to: joined, adaptiveWeight: WEIGHT_AUTO, index: 0)
        windows[0].bind(to: joined, adaptiveWeight: WEIGHT_AUTO, index: 0)
        preserveCurrentSmoothWorkspaceTreeAfterUserCommand(workspace)

        workspace.normalizeContainers()
        let normalizedManualTree = workspace.rootTilingContainer.layoutDescription
        reconcileSmoothWorkspaceLayouts()

        assertEquals(workspace.rootTilingContainer.layoutDescription, normalizedManualTree)
        assertNotEquals(
            workspace.rootTilingContainer.layoutDescription,
            expectedDwindle([1, 2, 3, 4], orientationIsHorizontal: true),
        )
    }

    func testSameShapePreservesManualWindowOrder() {
        enableStyle(.dwindle)
        let root = Workspace.get(byName: name).rootTilingContainer
        let windows = (1 ... 4).map { TestWindow.new(id: UInt32($0), parent: root) }
        reconcileSmoothWorkspaceLayouts()
        let originalTail = root.children[1]
        let deepestParent = windows[2].parent.orDie()

        windows[2].bind(to: deepestParent, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        reconcileSmoothWorkspaceLayouts()

        assertTrue(root.children.contains { $0 === originalTail })
        assertEquals(root.allLeafWindowsRecursive.map(\.windowId), [1, 2, 4, 3])
    }

    func testMonitorLimitMovesOverflowToAnotherWorkspaceOnSameMonitor() {
        SmoothLayoutSettingsStore.shared.replaceProfilesForTests([
            "Test Monitor": SmoothMonitorLayoutProfile(
                monitorName: "Test Monitor",
                enabled: true,
                tileLimit: 3,
                styles: Array(repeating: .dwindle, count: SmoothMonitorLayoutProfile.configuredWindowCount),
            ),
        ])
        let source = Workspace.get(byName: name)
        let destination = Workspace.get(byName: "secondary")
        _ = destination.rootTilingContainer
        (1 ... 5).forEach { TestWindow.new(id: UInt32($0), parent: source.rootTilingContainer) }

        reconcileSmoothWorkspaceLayouts()

        assertEquals(source.rootTilingContainer.allLeafWindowsRecursive.count, 3)
        assertEquals(destination.rootTilingContainer.allLeafWindowsRecursive.count, 2)
    }

    func testManualStylePreservesCustomTreeOrderAndWeights() {
        enableStyle(.manual)
        let root = Workspace.get(byName: name).rootTilingContainer
        let first = TestWindow.new(id: 1, parent: root, adaptiveWeight: 3)
        let tail = TilingContainer.newVTiles(parent: root, adaptiveWeight: 1)
        let second = TestWindow.new(id: 2, parent: tail, adaptiveWeight: 2)
        let third = TestWindow.new(id: 3, parent: tail, adaptiveWeight: 1)

        reconcileSmoothWorkspaceLayouts()
        reconcileSmoothWorkspaceLayouts()

        assertEquals(root.layoutDescription, .h_tiles([.window(1), .v_tiles([.window(2), .window(3)])]))
        assertTrue(first.parent === root)
        assertTrue(second.parent === tail)
        assertTrue(third.parent === tail)
        assertEquals(first.getWeight(.h), 3)
        assertEquals(tail.getWeight(.h), 1)
        assertEquals(second.getWeight(.v), 2)
        assertEquals(third.getWeight(.v), 1)
    }

    func testManualStyleReleasesAutoFullscreenOnlyOnTransition() {
        enableStyle(.fullscreen)
        let root = Workspace.get(byName: name).rootTilingContainer
        let window = TestWindow.new(id: 1, parent: root)
        reconcileSmoothWorkspaceLayouts()
        assertTrue(window.isFullscreen)

        SmoothLayoutSettingsStore.shared.replaceProfilesForTests(
            ["Test Monitor": profile(style: .manual)],
            invalidateSnapshots: false,
        )
        reconcileSmoothWorkspaceLayouts()
        assertFalse(window.isFullscreen)

        window.isFullscreen = true
        reconcileSmoothWorkspaceLayouts()
        assertTrue(window.isFullscreen)
    }

    func testPreviewProducesOneFramePerWindowForEveryStyleAndCount() {
        for style in SmoothLayoutStyle.allCases {
            for count in 1 ... 10 {
                let frames = SmoothLayoutPreviewGeometry.frames(
                    style: style,
                    count: count,
                    monitorIsHorizontal: true,
                )
                assertEquals(frames.count, style == .manual ? 0 : count)
                assertTrue(frames.allSatisfy {
                    $0.minX >= 0 && $0.minY >= 0 && $0.maxX <= 1 && $0.maxY <= 1 && $0.width > 0 && $0.height > 0
                })
            }
        }
    }

    func testAdaptiveHideUsesBottomEdgeWhenBothCornersLeakIntoSideMonitors() {
        let macBook = Rect(topLeftX: 0, topLeftY: 0, width: 1512, height: 982)
        let ultra = Rect(topLeftX: 1512, topLeftY: -523, width: 3780, height: 2160)
        let vertical = Rect(topLeftX: -1296, topLeftY: -594, width: 1296, height: 2304)
        let origin = adaptiveHideOrigin(
            monitorRect: macBook,
            screenRects: [macBook, ultra, vertical],
            windowSize: CGSize(width: 935, height: 600),
        )
        let hiddenWindow = CGRect(origin: origin, size: CGSize(width: 935, height: 600))
        let ultraFrame = CGRect(x: 1512, y: -523, width: 3780, height: 2160)
        let verticalFrame = CGRect(x: -1296, y: -594, width: 1296, height: 2304)

        assertEquals(origin, CGPoint(x: 288.5, y: 981))
        assertTrue(hiddenWindow.intersection(CGRect(x: 0, y: 0, width: 1512, height: 982)).height <= 1)
        assertTrue(hiddenWindow.intersection(ultraFrame).isNull)
        assertTrue(hiddenWindow.intersection(verticalFrame).isNull)
    }

    func testAdaptiveHideUsesCornerOnSingleMonitor() {
        let macBook = Rect(topLeftX: 0, topLeftY: 0, width: 1800, height: 1169)

        let origin = adaptiveHideOrigin(
            monitorRect: macBook,
            screenRects: [macBook],
            windowSize: CGSize(width: 888, height: 1060),
        )

        assertEquals(origin, CGPoint(x: 1799, y: 1168))
    }

    func testScratchpadHideOriginAcceptanceAllowsAxRounding() {
        assertTrue(hideOriginsAreEffectivelyEqual(
            CGPoint(x: 300, y: 900),
            CGPoint(x: 306, y: 893),
        ))
        assertFalse(hideOriginsAreEffectivelyEqual(
            CGPoint(x: 300, y: 900),
            CGPoint(x: 1638, y: -260),
        ))
    }

    func testWindowConstraintViolationAllowsSmallRoundingDifferences() {
        let target = Rect(topLeftX: 0, topLeftY: 0, width: 460, height: 520)

        assertFalse(smoothWindowExceedsTile(
            actual: Rect(topLeftX: 0, topLeftY: 0, width: 467, height: 528),
            target: target,
        ))
        assertTrue(smoothWindowExceedsTile(
            actual: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
            target: target,
        ))
    }

    func testConstraintFallbackDoesNotCancelUserFullscreen() async {
        enableStyle(.dwindle)
        let root = Workspace.get(byName: name).rootTilingContainer
        let windows = (1 ... 3).map { TestWindow.new(id: UInt32($0), parent: root) }
        reconcileSmoothWorkspaceLayouts()

        windows[0].isFullscreen = true
        await reconcileSmoothWorkspaceLayoutsRespectingWindowConstraints()

        assertTrue(windows[0].isFullscreen)
        assertEquals(root.layoutDescription, expectedDwindle([1, 2, 3], orientationIsHorizontal: true))
    }

    private func enableStyle(_ style: SmoothLayoutStyle) {
        SmoothLayoutSettingsStore.shared.replaceProfilesForTests(["Test Monitor": profile(style: style)])
    }

    private func profile(style: SmoothLayoutStyle) -> SmoothMonitorLayoutProfile {
        SmoothMonitorLayoutProfile(
            monitorName: "Test Monitor",
            enabled: true,
            tileLimit: 10,
            styles: Array(repeating: style, count: SmoothMonitorLayoutProfile.configuredWindowCount),
        )
    }

    private func expectedDwindle(_ ids: [UInt32], orientationIsHorizontal: Bool) -> LayoutDescription {
        let children: [LayoutDescription] = if ids.count <= 2 {
            ids.map(LayoutDescription.window)
        } else {
            [
                .window(ids[0]),
                expectedDwindle(Array(ids.dropFirst()), orientationIsHorizontal: !orientationIsHorizontal),
            ]
        }
        return orientationIsHorizontal ? .h_tiles(children) : .v_tiles(children)
    }

    private func expectedVerticalPairs(_ ids: [UInt32]) -> LayoutDescription {
        var children: [LayoutDescription] = []
        var index = 0
        while index < ids.count {
            let end = min(index + 2, ids.count)
            let row = ids[index ..< end].map(LayoutDescription.window)
            children.append(row.count == 1 ? row[0] : .h_tiles(row))
            index = end
        }
        return .v_tiles(children)
    }
}
