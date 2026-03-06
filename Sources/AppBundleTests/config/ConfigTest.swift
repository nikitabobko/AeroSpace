@testable import AppBundle
import Common
import XCTest

@MainActor
final class ConfigTest: XCTestCase {
    func testParseI3Config() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/i3-like-config-example.toml"), encoding: .utf8)
        let (i3Config, errors) = parseConfig(toml)
        assertEquals(errors, [])
        assertEquals(i3Config.execConfig, defaultConfig.execConfig)
        assertEquals(i3Config.enableNormalizationFlattenContainers, false)
        assertEquals(i3Config.enableNormalizationOppositeOrientationForNestedContainers, false)
    }

    func testParseDefaultConfig() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/default-config.toml"), encoding: .utf8)
        let (_, errors) = parseConfig(toml)
        assertEquals(errors, [])
    }

    func testConfigVersionOutOfBounds() {
        let (_, errors) = parseConfig(
            """
            config-version = 0
            """,
        )
        assertEquals(errors.descriptions, ["config-version: Must be in [1, 2] range"])
    }

    func testExecOnWorkspaceChangeDifferentTypesError() {
        let (_, errors) = parseConfig(
            """
            exec-on-workspace-change = ['', 1]
            """,
        )
        assertEquals(errors.descriptions, ["exec-on-workspace-change[1]: Expected type is \'string\'. But actual type is \'integer\'"])
    }

    func testDuplicatedPersistentWorkspaces() {
        let (_, errors) = parseConfig(
            """
            config-version = 2
            persistent-workspaces = ['a', 'a']
            """,
        )
        assertEquals(errors.descriptions, ["persistent-workspaces: Contains duplicated workspace names"])
    }

    func testPersistentWorkspacesAreAvailableOnlySinceVersion2() {
        let (_, errors) = parseConfig(
            """
            persistent-workspaces = ['a']
            """,
        )
        assertEquals(errors.descriptions, ["persistent-workspaces: This config option is only available since \'config-version = 2\'"])
    }

    func testQueryCantBeUsedInConfig() {
        let (_, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-a = 'list-apps'
            """,
        )
        XCTAssertTrue(errors.descriptions.singleOrNil()?.contains("cannot be used in config") == true)
    }

    func testDropBindings() {
        let (config, errors) = parseConfig(
            """
            mode.main = {}
            """,
        )
        assertEquals(errors, [])
        XCTAssertTrue(config.modes[mainModeId]?.bindings.isEmpty == true)
    }

    func testParseMode() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
            """,
        )
        assertEquals(errors, [])
        let binding = HotkeyBinding(.option, .h, [FocusCommand.new(direction: .left)])
        assertEquals(
            config.modes[mainModeId],
            Mode(bindings: [binding.descriptionWithKeyCode: binding]),
        )
    }

    func testParseModeInheritance() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
            [mode.resize]
                inherits = 'main'
            [mode.resize.binding]
                h = 'resize width -50'
            """,
        )
        assertEquals(errors, [])
        assertEquals(config.modes["resize"]?.inherits, "main")
        // After flattening, resize should have both bindings
        // Debug: print binding keys to understand format
        let resizeBindingKeys = config.modes["resize"]?.bindings.keys.sorted() ?? []
        let mainBindingKeys = config.modes[mainModeId]?.bindings.keys.sorted() ?? []
        // The binding keys should contain inherited bindings from main
        XCTAssertEqual(resizeBindingKeys.count, 2, "Expected 2 bindings, got \(resizeBindingKeys)")
        XCTAssertEqual(mainBindingKeys.count, 1, "Expected 1 main binding, got \(mainBindingKeys)")
    }

    func testCircularInheritanceError() {
        let (_, errors) = parseConfig(
            """
            [mode.main.binding]
            [mode.a]
                inherits = 'b'
            [mode.a.binding]
            [mode.b]
                inherits = 'a'
            [mode.b.binding]
            """,
        )
        XCTAssertTrue(errors.descriptions.contains { $0.contains("Circular inheritance") })
    }

    func testUndefinedParentModeError() {
        let (_, errors) = parseConfig(
            """
            [mode.main.binding]
            [mode.resize]
                inherits = 'nonexistent'
            [mode.resize.binding]
            """,
        )
        XCTAssertTrue(errors.descriptions.contains { $0.contains("undefined mode") })
    }

    func testParseAppModes() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
            [mode.firefox]
                app = 'org.mozilla.firefox'
                inherits = 'main'
            [mode.firefox.binding]
                ctrl-t = 'exec-and-forget echo test'
            """,
        )
        assertEquals(errors, [])
        assertEquals(config.appModes["org.mozilla.firefox"], "firefox")
        XCTAssertNotNil(config.modes["firefox"])
        assertEquals(config.modes["firefox"]?.app, "org.mozilla.firefox")
        // Should have 2 bindings: inherited alt-h from main + its own ctrl-t
        XCTAssertEqual(config.modes["firefox"]?.bindings.count, 2)
    }

    func testInheritanceBindingOverride() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
            [mode.vim]
                inherits = 'main'
            [mode.vim.binding]
                alt-h = 'focus right'
            """,
        )
        assertEquals(errors, [])
        // vim should have exactly 1 binding (alt-h overrides parent's alt-h)
        XCTAssertEqual(config.modes["vim"]?.bindings.count, 1)
        // Get the binding (using the key from main's binding which should be the same)
        let mainBinding = config.modes[mainModeId]?.bindings.values.first
        let vimBindingKey = mainBinding?.descriptionWithKeyCode ?? ""
        let binding = config.modes["vim"]?.bindings[vimBindingKey]
        // Should have child's command (focus right), not parent's (focus left)
        XCTAssertNotNil(binding)
        XCTAssertTrue(binding?.commands.first is FocusCommand)
        let focusCmd = binding?.commands.first as? FocusCommand
        // Verify it's focus right (child) not focus left (parent)
        assertEquals(focusCmd?.args.cardinalOrDfsDirection, .direction(.right))
    }

    func testDeepInheritanceChain() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
            [mode.base]
                inherits = 'main'
            [mode.base.binding]
                alt-j = 'focus down'
            [mode.child]
                inherits = 'base'
            [mode.child.binding]
                alt-k = 'focus up'
            """,
        )
        assertEquals(errors, [])
        // child should have all three bindings
        XCTAssertEqual(config.modes["child"]?.bindings.count, 3)
        // base should have 2 bindings (main's + its own)
        XCTAssertEqual(config.modes["base"]?.bindings.count, 2)
    }

    func testUnbindRemovesInheritedBindings() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
                alt-j = 'focus down'
                alt-k = 'focus up'
                alt-l = 'focus right'
            [mode.emacs]
                inherits = 'main'
                unbind = ['alt-h', 'alt-j', 'alt-k', 'alt-l']
            [mode.emacs.binding]
                ctrl-x = 'exec-and-forget echo test'
            """,
        )
        assertEquals(errors, [])
        // main should have 4 bindings
        XCTAssertEqual(config.modes[mainModeId]?.bindings.count, 4)
        // emacs should have only 1 binding (ctrl-x), all alt-* removed
        XCTAssertEqual(config.modes["emacs"]?.bindings.count, 1)
        // Verify the remaining binding is ctrl-x, not any of the unbound ones
        let bindingKeys = config.modes["emacs"]?.bindings.keys.map { $0 } ?? []
        XCTAssertTrue(bindingKeys.allSatisfy { !$0.contains("alt") })
    }

    func testUnbindPartialRemoval() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
                alt-j = 'focus down'
                alt-k = 'focus up'
            [mode.vim]
                inherits = 'main'
                unbind = ['alt-h']
            [mode.vim.binding]
            """,
        )
        assertEquals(errors, [])
        // vim should have 2 bindings (alt-j and alt-k, but not alt-h)
        XCTAssertEqual(config.modes["vim"]?.bindings.count, 2)
    }

    func testModesMustContainDefaultModeError() {
        let (config, errors) = parseConfig(
            """
            [mode.foo.binding]
                alt-h = 'focus left'
            """,
        )
        assertEquals(
            errors.descriptions,
            ["mode: Please specify \'main\' mode"],
        )
        assertEquals(config.modes[mainModeId], nil)
    }

    func testHotkeyParseError() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-hh = 'focus left'
                aalt-j = 'focus down'
                alt-k = 'focus up'
            """,
        )
        assertEquals(
            errors.descriptions,
            [
                "mode.main.binding.aalt-j: Can\'t parse modifiers in \'aalt-j\' binding",
                "mode.main.binding.alt-hh: Can\'t parse the key in \'alt-hh\' binding",
            ],
        )
        let binding = HotkeyBinding(.option, .k, [FocusCommand.new(direction: .up)])
        assertEquals(
            config.modes[mainModeId],
            Mode(bindings: [binding.descriptionWithKeyCode: binding]),
        )
    }

    func testPermanentWorkspaceNames() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-1 = 'workspace 1'
                alt-2 = 'workspace 2'
                alt-3 = ['workspace 3']
                alt-4 = ['workspace 4', 'focus left']
            """,
        )
        assertEquals(errors.descriptions, [])
        assertEquals(config.persistentWorkspaces.sorted(), ["1", "2", "3", "4"])
    }

    func testUnknownTopLevelKeyParseError() {
        let (config, errors) = parseConfig(
            """
            unknownKey = true
            enable-normalization-flatten-containers = false
            """,
        )
        assertEquals(
            errors.descriptions,
            ["unknownKey: Unknown top-level key"],
        )
        assertEquals(config.enableNormalizationFlattenContainers, false)
    }

    func testUnknownKeyParseError() {
        let (config, errors) = parseConfig(
            """
            enable-normalization-flatten-containers = false
            [gaps]
                unknownKey = true
            """,
        )
        assertEquals(
            errors.descriptions,
            ["gaps.unknownKey: Unknown key"],
        )
        assertEquals(config.enableNormalizationFlattenContainers, false)
    }

    func testTypeMismatch() {
        let (_, errors) = parseConfig(
            """
            enable-normalization-flatten-containers = 'true'
            """,
        )
        assertEquals(
            errors.descriptions,
            ["enable-normalization-flatten-containers: Expected type is \'bool\'. But actual type is \'string\'"],
        )
    }

    func testTomlParseError() {
        let (_, errors) = parseConfig("true")
        assertEquals(
            errors.descriptions,
            ["Error while parsing key-value pair: encountered end-of-file (at line 1, column 5)"],
        )
    }

    func testMoveWorkspaceToMonitorCommandParsing() {
        XCTAssertTrue(parseCommand("move-workspace-to-monitor --wrap-around next").cmdOrNil is MoveWorkspaceToMonitorCommand)
        XCTAssertTrue(parseCommand("move-workspace-to-display --wrap-around next").cmdOrNil is MoveWorkspaceToMonitorCommand)
    }

    func testParseTiles() {
        let command = parseCommand("layout tiles h_tiles v_tiles list h_list v_list").cmdOrNil
        XCTAssertTrue(command is LayoutCommand)
        assertEquals((command as! LayoutCommand).args.toggleBetween.val, [.tiles, .h_tiles, .v_tiles, .tiles, .h_tiles, .v_tiles])

        guard case .help = parseCommand("layout tiles -h") else {
            XCTFail()
            return
        }
    }

    func testSplitCommandAndFlattenContainersNormalization() {
        let (_, errors) = parseConfig(
            """
            enable-normalization-flatten-containers = true
            [mode.main.binding]
            [mode.foo.binding]
                alt-s = 'split horizontal'
            """,
        )
        assertEquals(
            ["""
                The config contains:
                1. usage of 'split' command
                2. enable-normalization-flatten-containers = true
                These two settings don't play nicely together. 'split' command has no effect when enable-normalization-flatten-containers is disabled.

                My recommendation: keep the normalizations enabled, and prefer 'join-with' over 'split'.
                """],
            errors.descriptions,
        )
    }

    func testParseWorkspaceToMonitorAssignment() {
        let (parsed, errors) = parseConfig(
            """
            [workspace-to-monitor-force-assignment]
                workspace_name_1 = 1                            # Sequence number of the monitor (from left to right, 1-based indexing)
                workspace_name_2 = 'main'                       # main monitor
                workspace_name_3 = 'secondary'                  # non-main monitor (in case when there are only two monitors)
                workspace_name_4 = 'built-in'                   # case insensitive regex substring
                workspace_name_5 = '^built-in retina display$'  # case insensitive regex match
                workspace_name_6 = ['secondary', 1]             # you can specify multiple patterns. The first matching pattern will be used
                7 = "foo"
                w7 = ['', 'main']
                w8 = 0
                workspace_name_x = '2'                          # Sequence number of the monitor (from left to right, 1-based indexing)
            """,
        )
        assertEquals(
            parsed.workspaceToMonitorForceAssignment,
            [
                "workspace_name_1": [.sequenceNumber(1)],
                "workspace_name_2": [.main],
                "workspace_name_3": [.secondary],
                "workspace_name_4": [.caseSensitivePattern("built-in")!],
                "workspace_name_5": [.caseSensitivePattern("^built-in retina display$")!],
                "workspace_name_6": [.secondary, .sequenceNumber(1)],
                "workspace_name_x": [.sequenceNumber(2)],
                "7": [.caseSensitivePattern("foo")!],
                "w7": [.main],
                "w8": [],
            ],
        )
        assertEquals([
            "workspace-to-monitor-force-assignment.w7[0]: Empty string is an illegal monitor description",
            "workspace-to-monitor-force-assignment.w8: Monitor sequence numbers uses 1-based indexing. Values less than 1 are illegal",
        ], errors.descriptions)
        assertEquals([:], defaultConfig.workspaceToMonitorForceAssignment)
    }

    func testParseOnWindowDetected() {
        let (parsed, errors) = parseConfig(
            """
            [[on-window-detected]] # 0
                check-further-callbacks = true
                run = ['layout floating', 'move-node-to-workspace W']
            [[on-window-detected]] # 1
                if.app-id = 'com.apple.systempreferences'
                run = []
            [[on-window-detected]] # 2
            [[on-window-detected]] # 3
                run = ['move-node-to-workspace S', 'layout tiling']
            [[on-window-detected]] # 4
                run = ['move-node-to-workspace S', 'move-node-to-workspace W']
            [[on-window-detected]] # 5
                run = ['move-node-to-workspace S', 'layout h_tiles']
            """,
        )
        assertEquals(parsed.onWindowDetected, [
            WindowDetectedCallback( // 0
                matcher: WindowDetectedCallbackMatcher(
                    appId: nil,
                    appNameRegexSubstring: nil,
                    windowTitleRegexSubstring: nil,
                ),
                checkFurtherCallbacks: true,
                rawRun: [
                    LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.floating])),
                    MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "W")),
                ],
            ),
            WindowDetectedCallback( // 1
                matcher: WindowDetectedCallbackMatcher(
                    appId: "com.apple.systempreferences",
                    appNameRegexSubstring: nil,
                    windowTitleRegexSubstring: nil,
                ),
                rawRun: [],
            ),
            WindowDetectedCallback( // 3
                rawRun: [
                    MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "S")),
                    LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiling])),
                ],
            ),
            WindowDetectedCallback( // 4
                rawRun: [
                    MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "S")),
                    MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "W")),
                ],
            ),
            WindowDetectedCallback( // 5
                rawRun: [
                    MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "S")),
                    LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.h_tiles])),
                ],
            ),
        ])

        assertEquals(errors.descriptions, [
            "on-window-detected[2]: \'run\' is mandatory key",
        ])
    }

    func testParseOnWindowDetectedRegex() {
        let (config, errors) = parseConfig(
            """
            [[on-window-detected]]
                if.app-name-regex-substring = '^system settings$'
                run = []
            """,
        )
        XCTAssertTrue(config.onWindowDetected.singleOrNil()!.matcher.appNameRegexSubstring != nil)
        assertEquals(errors, [])
    }

    func testRegex() {
        var devNull: [String] = []
        XCTAssertTrue("System Settings".contains(parseCaseInsensitiveRegex("settings").getOrNil(appendErrorTo: &devNull)!))
        XCTAssertTrue(!"System Settings".contains(parseCaseInsensitiveRegex("^settings^").getOrNil(appendErrorTo: &devNull)!))
    }

    func testParseGaps() {
        let (config, errors1) = parseConfig(
            """
            [gaps]
                inner.horizontal = 10
                inner.vertical = [{ monitor."main" = 1 }, { monitor."secondary" = 2 }, 5]
                outer.left = 12
                outer.bottom = 13
                outer.top = [{ monitor."built-in" = 3 }, { monitor."secondary" = 4 }, 6]
                outer.right = [{ monitor.2 = 7 }, 8]
            """,
        )
        assertEquals(errors1, [])
        assertEquals(
            config.gaps,
            Gaps(
                inner: .init(
                    vertical: .perMonitor(
                        [PerMonitorValue(description: .main, value: 1), PerMonitorValue(description: .secondary, value: 2)],
                        default: 5,
                    ),
                    horizontal: .constant(10),
                ),
                outer: .init(
                    left: .constant(12),
                    bottom: .constant(13),
                    top: .perMonitor(
                        [
                            PerMonitorValue(description: .caseSensitivePattern("built-in")!, value: 3),
                            PerMonitorValue(description: .secondary, value: 4),
                        ],
                        default: 6,
                    ),
                    right: .perMonitor([PerMonitorValue(description: .sequenceNumber(2), value: 7)], default: 8),
                ),
            ),
        )

        let (_, errors2) = parseConfig(
            """
            [gaps]
                inner.horizontal = [true]
                inner.vertical = [{ foo.main = 1 }, { monitor = { foo = 2, bar = 3 } }, 1]
            """,
        )
        assertEquals(errors2.descriptions, [
            "gaps.inner.horizontal: The last item in the array must be of type Int",
            "gaps.inner.vertical[0]: The table is expected to have a single key \'monitor\'",
            "gaps.inner.vertical[1].monitor: The table is expected to have a single key",
        ])
    }

    func testParseKeyMapping() {
        let (config, errors) = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
                q = 'q'
                unicorn = 'u'

            [mode.main.binding]
                alt-unicorn = 'workspace wonderland'
            """,
        )
        assertEquals(errors.descriptions, [])
        assertEquals(config.keyMapping, KeyMapping(preset: .qwerty, rawKeyNotationToKeyCode: [
            "q": .q,
            "unicorn": .u,
        ]))
        let binding = HotkeyBinding(.option, .u, [WorkspaceCommand(args: WorkspaceCmdArgs(target: .direct(.parse("unicorn").getOrDie())))])
        assertEquals(config.modes[mainModeId]?.bindings, [binding.descriptionWithKeyCode: binding])

        let (_, errors1) = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
                q = 'qw'
                ' f' = 'f'
            """,
        )
        assertEquals(errors1.descriptions, [
            "key-mapping.key-notation-to-key-code: ' f' is invalid key notation",
            "key-mapping.key-notation-to-key-code.q: 'qw' is invalid key code",
        ])

        let (dvorakConfig, dvorakErrors) = parseConfig(
            """
            key-mapping.preset = 'dvorak'
            """,
        )
        assertEquals(dvorakErrors, [])
        assertEquals(dvorakConfig.keyMapping, KeyMapping(preset: .dvorak, rawKeyNotationToKeyCode: [:]))
        assertEquals(dvorakConfig.keyMapping.resolve()["quote"], .q)
        let (colemakConfig, colemakErrors) = parseConfig(
            """
            key-mapping.preset = 'colemak'
            """,
        )
        assertEquals(colemakErrors, [])
        assertEquals(colemakConfig.keyMapping, KeyMapping(preset: .colemak, rawKeyNotationToKeyCode: [:]))
        assertEquals(colemakConfig.keyMapping.resolve()["f"], .e)
    }
}
