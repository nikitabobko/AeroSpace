@testable import AppBundle
import Common
import XCTest

@MainActor
final class LayoutCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // MARK: - Happy paths

    func testRoot_togglesTilesToAccordion_preservesNestedStructure() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 1, parent: $0)
                    TestWindow.new(id: 2, parent: $0)
                }
            }
        }
        assertEquals(workspace.focusWorkspace(), true)
        assertEquals(workspace.rootTilingContainer.layout, .tiles)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles, .accordion], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.rootTilingContainer.layout, .accordion)
        // Orientation preserved (descriptor list `[tiles, accordion]` only mutates layout); root stays h.
        assertEquals(workspace.layoutDescription, .workspace([
            .h_accordion([
                .h_tiles([.window(1), .window(2)]),
            ]),
        ]))
    }

    func testRoot_togglesAccordionToTiles() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                $0.layout = .accordion
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 1, parent: $0)
                    TestWindow.new(id: 2, parent: $0)
                }
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles, .accordion], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.rootTilingContainer.layout, .tiles)
    }

    func testRoot_togglesOrientationOnly() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
                TestWindow.new(id: 2, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)
        assertEquals(workspace.rootTilingContainer.orientation, .h)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.horizontal, .vertical], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.rootTilingContainer.orientation, .v)
        assertEquals(workspace.rootTilingContainer.layout, .tiles)
    }

    func testRoot_ensureTilesAndToggleOrientation_fromTiles() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles, .horizontal, .vertical], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.rootTilingContainer.layout, .tiles)
        assertEquals(workspace.rootTilingContainer.orientation, .v)
    }

    func testRoot_ensureTilesAndToggleOrientation_fromAccordion() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                $0.layout = .accordion
                TestWindow.new(id: 1, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles, .horizontal, .vertical], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.rootTilingContainer.layout, .tiles)
        assertEquals(workspace.rootTilingContainer.orientation, .h)
    }

    func testRoot_compoundDescriptor_setsBothFields() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.h_accordion], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.rootTilingContainer.layout, .accordion)
        assertEquals(workspace.rootTilingContainer.orientation, .h)
    }

    // MARK: - Edge cases

    func testRoot_succeedsOnEmptyWorkspace() async throws {
        let workspace = Workspace.get(byName: name)
        assertEquals(workspace.focusWorkspace(), true)
        assertEquals(workspace.isEffectivelyEmpty, true)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles, .accordion], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.rootTilingContainer.layout, .accordion)
    }

    func testRoot_succeedsOnFloatingOnlyWorkspace() async throws {
        let workspace = Workspace.get(byName: name).apply {
            TestWindow.new(id: 1, parent: $0) // floating
        }
        assertEquals(workspace.focusWorkspace(), true)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles, .accordion], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.rootTilingContainer.layout, .accordion)
        assertEquals(workspace.floatingWindows.count, 1)
    }

    func testRoot_noopReturnsFail_whenAlreadyMatchesDescriptor() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)
        assertEquals(workspace.rootTilingContainer.layout, .tiles)

        let result = try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(workspace.rootTilingContainer.layout, .tiles)
    }

    func testRoot_overridesFocusOnNestedSubContainer() async throws {
        var nestedAccordion: TilingContainer!
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TilingContainer(parent: $0, adaptiveWeight: 1, .h, .accordion, index: INDEX_BIND_LAST).apply {
                    nestedAccordion = $0
                    assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
                }
            }
        }
        assertEquals(workspace.rootTilingContainer.layout, .tiles)
        assertEquals(nestedAccordion.layout, .accordion)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles, .accordion], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.rootTilingContainer.layout, .accordion)
        assertEquals(nestedAccordion.layout, .accordion) // unchanged
    }

    // MARK: - Error paths

    func testParse_rootRejectsFloatingDescriptor() {
        assertEquals(
            parseCommand("layout --root floating").errorOrNil,
            "'tiling' and 'floating' are incompatible with --root",
        )
    }

    func testParse_rootRejectsTilingDescriptor() {
        assertEquals(
            parseCommand("layout --root tiling").errorOrNil,
            "'tiling' and 'floating' are incompatible with --root",
        )
    }

    func testParse_rootRejectsTilingInToggleList() {
        assertEquals(
            parseCommand("layout --root tiling accordion").errorOrNil,
            "'tiling' and 'floating' are incompatible with --root",
        )
    }

    func testParse_rootConflictsWithWindowId() {
        assertEquals(
            parseCommand("layout --root --window-id 12345 tiles").errorOrNil,
            "ERROR: Conflicting options: --root, --window-id",
        )
    }

    // MARK: - Integration with normalization

    func testRoot_oppositeOrientationNormalizationRenormalizesDescendants() async throws {
        // Documents the interaction between --root orientation toggling and enableNormalizationOppositeOrientationForNestedContainers.
        // changeOrientation walks parentsWithSelf only (so the call itself does not touch descendants), but every command flows through
        // refreshModel() -> normalizeContainers() -> normalizeOppositeOrientationForNestedContainers, which DOES recurse into descendants
        // and flips any child whose orientation matches its parent. After this command, the nested container ends up opposite the root.
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        var nestedTilesV: TilingContainer!
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TilingContainer(parent: $0, adaptiveWeight: 1, .v, .tiles, index: INDEX_BIND_LAST).apply {
                    nestedTilesV = $0
                    TestWindow.new(id: 1, parent: $0)
                    TestWindow.new(id: 2, parent: $0)
                }
            }
        }
        assertEquals(workspace.focusWorkspace(), true)
        assertEquals(workspace.rootTilingContainer.orientation, .h)
        assertEquals(nestedTilesV.orientation, .v)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.horizontal, .vertical], root: true))
            .run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.rootTilingContainer.orientation, .v)
        // Post-command normalize flips nested to opposite of root (was v matching root v -> flipped to h).
        assertEquals(nestedTilesV.orientation, .h)
    }

    func testRoot_flattenNormalizationDiscardsRootToggle_whenSingleNestedContainer() async throws {
        // Documents a known limitation of enableNormalizationFlattenContainers (see Sources/AppBundle/tree/normalizeContainers.swift line 12).
        // The line-12 condition `child is TilingContainer || !isRootContainer` flattens the root when its sole child is a TilingContainer.
        // After --root toggles the (about-to-be-discarded) root's layout, the next normalize pass replaces the root with the nested
        // container, carrying its original layout. The --root toggle is effectively lost under this specific tree shape.
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                    TestWindow.new(id: 1, parent: $0)
                }
            }
        }
        assertEquals(workspace.focusWorkspace(), true)
        assertEquals(workspace.rootTilingContainer.layout, .tiles)

        try await LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiles, .accordion], root: true))
            .run(.defaultEnv, .emptyStdin)
        assertEquals(workspace.rootTilingContainer.layout, .accordion)

        config.enableNormalizationFlattenContainers = true
        workspace.normalizeContainers()

        // The formerly-nested h_tiles container is now the root; the --root accordion toggle is discarded.
        assertEquals(workspace.rootTilingContainer.layout, .tiles)
        assertEquals(workspace.rootTilingContainer.orientation, .h)
    }
}
