@testable import AppBundle
import Common
import CoreGraphics
import Testing

@MainActor
@Suite(.serializedGlobally)
struct LayoutSkeletonTest {
    init() { setUpWorkspacesForTests() }

    @Test func testParse_masterStack() {
        assertEquals(
            parse("h_tiles[1@0.6, v_tiles[others]]"),
            LayoutSkeleton(root: .init(
                orientation: .h,
                children: [
                    .placeholder(1, weight: 0.6),
                    .container(.init(orientation: .v, children: [.others()])),
                ],
            )),
        )
    }

    @Test func testParse_indentedSyntax() {
        let skeleton = parse("""
            h_tiles
              1 @0.55
              v_tiles
                others
            """)
        assertEquals(
            skeleton,
            LayoutSkeleton(root: .init(
                orientation: .h,
                children: [
                    .placeholder(1, weight: 0.55),
                    .container(.init(orientation: .v, children: [.others()])),
                ],
            )),
        )
    }

    @Test func testParse_indentedSyntax_ignoresBlankLines() {
        let skeleton = parse("""
            h_tiles

              1

              v_tiles
                others

            """)
        assertEquals(skeleton.root.children.count, 2)
    }

    @Test func testParse_indentedSyntax_errors() {
        assertParseError("h_tiles\n  1\n    2\n  others", "Inconsistent indentation")
        assertParseError("h_tiles\n\t1\n\tothers", "Tabs aren't allowed")
        assertParseError("h_tiles", "must contain at least one child")
        assertParseError("h_tiles\n  1", "must appear exactly once")
        assertParseError("h_tiles\n  1 @0.6\n  2 @0.5\n  others", "sum to less than 1")
        assertParseError("h_tiles\n  1 @0\n  others", "Weight must be a positive number")
    }

    @Test func testParse_weights() {
        let skeleton = parse("h_tiles[v_tiles[1, 2]@0.6, v_tiles[others]]")
        assertEquals(skeleton.root.children.first?.containerWeight, 0.6)
        assertEquals(skeleton.root.children.last?.containerWeight, nil)
    }

    @Test func testParse_whitespaceAndNewlines() {
        let skeleton = parse("""
            h_tiles [
              1 @ 0.6,
              v_tiles [ others ]
            ]
            """)
        assertEquals(skeleton.root.orientation, .h)
        assertEquals(skeleton.root.placeholderCount, 1)
    }

    @Test func testParse_errors() {
        assertParseError("h_tiles[1]", "must appear exactly once")
        assertParseError("h_tiles[others, others]", "must appear exactly once")
        assertParseError("h_tiles[1, 1, others]", "Duplicate placeholder 1")
        assertParseError("h_tiles[0, others]", "start from 1")
        assertParseError("columns[others]", "Expected 'h_tiles' or 'v_tiles'")
        assertParseError("h_tiles[", "Unexpected end of input")
        assertParseError("h_tiles[1, others] v_tiles[others]", "trailing characters")
        assertParseError("h_tiles[1@0, others]", "Weight must be a positive number")
    }

    private func assertParseError(_ source: String, _ expectedSubstring: String, sourceLocation: SourceLocation = #_sourceLocation) {
        switch LayoutSkeleton.parse(source) {
            case .success(let skeleton):
                Issue.record("Expected a parse error. Got: \(skeleton)", sourceLocation: sourceLocation)
            case .failure(let error):
                if !error.description.contains(expectedSubstring) {
                    Issue.record("Expected '\(expectedSubstring)' in '\(error.description)'", sourceLocation: sourceLocation)
                }
        }
    }

    // MARK: - Config

    @Test func testConfig_parsing() {
        let result = parseConfig("""
            [workspace-layout]
            '1' = 'h_tiles[1@0.6, v_tiles[others]]'
            '2' = 'h_tiles[others]'
            """)
        assertEquals(result.errors, [])
        assertEquals(result.config.workspaceLayout.keys.sorted(), ["1", "2"])
        assertEquals(result.config.workspaceLayout["1"]?.root.orientation, .h)
    }

    @Test func testConfig_indentedSyntax() {
        let result = parseConfig("""
            [workspace-layout]
            '1' = '''
            h_tiles
              1 @0.55
              v_tiles
                others
            '''
            """)
        assertEquals(result.errors, [])
        assertEquals(result.config.workspaceLayout["1"]?.root.placeholderCount, 1)
    }

    @Test func testConfig_errorIsReported() {
        let result = parseConfig("""
            [workspace-layout]
            '1' = 'h_tiles[1]'
            """)
        assertEquals(result.errors.count, 1)
        assertEquals(result.config.workspaceLayout, [:])
    }

    // MARK: - Normalization

    @Test func testNormalize_masterStack() {
        config.workspaceLayout = [name: skeleton("h_tiles[1@0.6, v_tiles[others]]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(3) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        let root = workspace.rootTilingContainer
        assertEquals(
            root.layoutDescription,
            .h_tiles([.window(0), .v_tiles([.window(1), .window(2)])]),
        )
        assertShare(root.children[0], of: root.children, 0.6)
        assertShare(root.children[1], of: root.children, 0.4)
    }

    @Test func testNormalize_weightsArePixelsNotFractions() {
        config.workspaceLayout = [name: skeleton("h_tiles[1@0.55, v_tiles[others]]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(3) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        let root = workspace.rootTilingContainer
        let width = workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps.width
        assertApproximatelyEqual(root.children[0].getWeight(.h), 0.55 * width)
        assertApproximatelyEqual(root.children[1].getWeight(.h), 0.45 * width)
    }

    @Test func testNormalize_nestedWeightsUseTheParentAxis() {
        config.workspaceLayout = [name: skeleton("h_tiles[v_tiles[1, 2]@0.6, v_tiles[others]]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(4) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        let root = workspace.rootTilingContainer
        let height = workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps.height
        let masterColumn = root.children[0]
        assertApproximatelyEqual(masterColumn.getWeight(.h), 0.6 * workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps.width)
        assertEquals(masterColumn.children.count, 2)
        assertApproximatelyEqual(masterColumn.children[0].getWeight(.v), 0.5 * height)
    }

    @Test func testNormalize_twoMasters() {
        config.workspaceLayout = [name: skeleton("h_tiles[v_tiles[1, 2]@0.6, v_tiles[others]]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(4) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([.v_tiles([.window(0), .window(1)]), .v_tiles([.window(2), .window(3)])]),
        )
    }

    @Test func testNormalize_masterOnTheRight() {
        // Windows fill the slots in the order the slots appear in the skeleton, so the resolved tree preserves the
        // visual order of the windows and the pass is a fixed point: the second pass must not change anything
        config.workspaceLayout = [name: skeleton("h_tiles[v_tiles[others], 1]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(3) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([.v_tiles([.window(0), .window(1)]), .window(2)]),
        )
        workspace.normalizeContainers()
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([.v_tiles([.window(0), .window(1)]), .window(2)]),
        )
    }

    @Test func testNormalize_slotsFilledInSkeletonOrder() {
        // The numbers don't order the slots: window 0 goes to the first slot of the skeleton, which is slot '2' here
        config.workspaceLayout = [name: skeleton("h_tiles[2, 1, others]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(2) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([.window(0), .window(1)]),
        )
    }

    @Test func testNormalize_containerWeightSurvivesCollapse() {
        // 'v_tiles' collapses to a single window, but its weight must survive: the stack takes 0.4 of the width
        config.workspaceLayout = [name: skeleton("h_tiles[1, v_tiles[others]@0.4]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(2) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        let root = workspace.rootTilingContainer
        assertEquals(
            root.layoutDescription,
            .h_tiles([.window(0), .window(1)]),
        )
        assertShare(root.children[0], of: root.children, 0.6)
        assertShare(root.children[1], of: root.children, 0.4)
    }

    @Test func testNormalize_rebuildsWhenMonitorGeometryChanges() {
        config.workspaceLayout = [name: skeleton("h_tiles[1@0.6, v_tiles[others]]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(3) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        let root = workspace.rootTilingContainer
        let widthBefore = workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps.width
        assertApproximatelyEqual(root.children[0].getWeight(.h), 0.6 * widthBefore)

        config.gaps.outer.left = .constant(100) // Shrinks the visible area like a display change would
        workspace.normalizeContainers()
        let widthAfter = workspace.workspaceMonitorInfo.visibleRectPaddedByOuterGaps.width
        assertApproximatelyEqual(widthAfter, widthBefore - 100)
        assertApproximatelyEqual(root.children[0].getWeight(.h), 0.6 * widthAfter)
    }

    @Test func testNormalize_rebuildsWhenSkeletonChanges() {
        // A config reload may replace the skeleton with a different one of the same shape (here: new weights).
        // The tree must be rebuilt even though the shape still matches and the monitor didn't change
        config.workspaceLayout = [name: skeleton("h_tiles[1@0.6, v_tiles[others]]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(3) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        let root = workspace.rootTilingContainer
        assertShare(root.children[0], of: root.children, 0.6)

        config.workspaceLayout = [name: skeleton("h_tiles[1@0.8, v_tiles[others]]")]
        workspace.normalizeContainers()
        assertShare(root.children[0], of: root.children, 0.8)
    }

    @Test func testNormalize_columns() {
        config.workspaceLayout = [name: skeleton("h_tiles[others]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(3) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([.window(0), .window(1), .window(2)]),
        )
    }

    @Test func testNormalize_unfilledPlaceholdersCollapse() {
        config.workspaceLayout = [name: skeleton("v_tiles[1, 2, h_tiles[others]]")]
        let workspace = Workspace.get(byName: name)
        TestWindow.new(id: 0, parent: workspace.rootTilingContainer)
        TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        workspace.normalizeContainers()
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .v_tiles([.window(0), .window(1)]),
        )
    }

    @Test func testNormalize_worksWithFlattenNormalizationEnabled() {
        config.workspaceLayout = [name: skeleton("h_tiles[1@0.6, v_tiles[others]]")]
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        for id in uids(3) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([.window(0), .v_tiles([.window(1), .window(2)])]),
        )
        workspace.normalizeContainers() // Idempotent under flatten normalization
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([.window(0), .v_tiles([.window(1), .window(2)])]),
        )
    }

    @Test func testNormalize_isIdempotentAndPreservesManualResize() {
        config.workspaceLayout = [name: skeleton("h_tiles[1@0.6, v_tiles[others]]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(3) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        let root = workspace.rootTilingContainer
        let stack = root.children[1]
        stack.setWeight(.h, 0.3)
        root.children[0].setWeight(.h, 0.2)

        workspace.normalizeContainers()
        assertEquals(
            root.layoutDescription,
            .h_tiles([.window(0), .v_tiles([.window(1), .window(2)])]),
        )
        // The shape still matches the skeleton and the monitor didn't change, so the tree isn't rebuilt
        assertEquals(stack.getWeight(.h), 0.3)
        assertEquals(root.children[0].getWeight(.h), 0.2)
    }

    @Test func testNormalize_doesntAffectOtherWorkspaces() {
        config.workspaceLayout = [name: skeleton("h_tiles[1@0.6, v_tiles[others]]")]
        let workspace = Workspace.get(byName: name)
        for id in uids(3) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        let otherWorkspace = Workspace.get(byName: "\(name)_other")
        for id in uids(3, offset: 3) {
            TestWindow.new(id: id, parent: otherWorkspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        otherWorkspace.normalizeContainers()
        assertEquals(
            otherWorkspace.rootTilingContainer.layoutDescription,
            .h_tiles([.window(3), .window(4), .window(5)]),
        )
    }

    @Test func testNormalize_skipsAccordion() {
        config.workspaceLayout = [name: skeleton("h_tiles[1@0.6, v_tiles[others]]")]
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.layout = .accordion
        for id in uids(3) {
            TestWindow.new(id: id, parent: workspace.rootTilingContainer)
        }
        workspace.normalizeContainers()
        assertEquals(
            workspace.rootTilingContainer.layoutDescription,
            .h_accordion([.window(0), .window(1), .window(2)]),
        )
    }

    private func assertShare(
        _ node: TreeNode,
        of siblings: [TreeNode],
        _ expected: CGFloat,
        orientation: Orientation = .h,
        sourceLocation: SourceLocation = #_sourceLocation,
    ) {
        let total = siblings.reduce(0) { $0 + $1.getWeight(orientation) }
        let actual = total != 0 ? node.getWeight(orientation) / total : 0
        if abs(actual - expected) > 0.001 {
            Issue.record("Expected share \(expected), got \(actual)", sourceLocation: sourceLocation)
        }
    }

    private func assertApproximatelyEqual(
        _ actual: CGFloat,
        _ expected: CGFloat,
        sourceLocation: SourceLocation = #_sourceLocation,
    ) {
        if abs(actual - expected) > 0.001 {
            Issue.record("Expected \(expected), got \(actual)", sourceLocation: sourceLocation)
        }
    }

    private func skeleton(_ source: String) -> LayoutSkeleton { parse(source) }

    private func parse(_ source: String) -> LayoutSkeleton {
        switch LayoutSkeleton.parse(source) {
            case .success(let skeleton): return skeleton
            case .failure(let error): fatalError("Can't parse '\(source)': \(error.description)")
        }
    }

    private func uids(_ count: UInt64, offset: UInt64 = 0) -> [OpaqueWindowId] {
        (offset ..< offset + count).map { OpaqueWindowId($0) }
    }
}

extension LayoutSkeleton.Node {
    fileprivate var containerWeight: Double? {
        switch self {
            case .container(let container): container.weight
            case .placeholder(_, let weight): weight
            case .others(let weight): weight
        }
    }
}
