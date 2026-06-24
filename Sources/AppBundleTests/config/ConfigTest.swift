@testable import AppBundle
import Common
import XCTest

@MainActor
final class ConfigTest: XCTestCase {
    func testParseI3Config() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/i3-like-config-example.toml"), encoding: .utf8)
        let result = parseConfig(toml)
        assertEquals(result.errors, [])
        assertEquals(result.warnings, [])
        assertEquals(result.config.execConfig, defaultConfig.execConfig)
        assertEquals(result.config.enableNormalizationFlattenContainers, false)
        assertEquals(result.config.enableNormalizationOppositeOrientationForNestedContainers, false)
    }

    func testEmptyConfig() {
        let result = parseConfig("")
        assertEquals(result.errors, [])
        assertTrue(result.allowReloadConfig)
        assertEquals(result.warnings.count, 1)
        assertTrue(result.strWarnings.first?.starts(with: "[WARNING] The current 'config-version = 1' is outdated.") == true)
    }

    func testParseDefaultConfig() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/default-config.toml"), encoding: .utf8)
        let result = parseConfig(toml)
        assertEquals(result.errors, [])
        assertEquals(result.warnings, [])
    }

    func testConfigVersionOutOfBounds() {
        let result = parseConfig(
            """
            config-version = 0
            """,
        )
        assertTrue(result.allowReloadConfig)
        assertEquals(result.strErrors, ["[ERROR] config-version: config-version must be in [1, 2] range"])
    }

    func testConfigVersionOutdatedWarning() {
        let result = parseConfig(
            """
            config-version = 1
            """,
        )
        assertTrue(result.allowReloadConfig)
        assertEquals(result.errors, [])
        assertEquals(result.strWarnings, [
            "[WARNING] The current 'config-version = 1' is outdated. " +
                "Please consider migrating to 'config-version = \(ConfigVersion.max)'. " +
                "See https://nikitabobko.github.io/AeroSpace/guide#config-version for the migration guide.",
        ])
    }

    func testLatestConfigVersionNoWarning() {
        let result = parseConfig(
            """
            config-version = \(ConfigVersion.max)
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.warnings, [])
    }

    func testExecOnWorkspaceChangeDifferentTypesError() {
        let errors = parseConfig(
            """
            exec-on-workspace-change = ['', 1]
            """,
        ).strErrors
        assertEquals(errors, ["[ERROR] exec-on-workspace-change[1]: Expected type is \'String\'. But actual type is \'Int\'"])
    }

    func testDuplicatedPersistentWorkspaces() {
        let errors = parseConfig(
            """
            config-version = 2
            persistent-workspaces = ['a', 'a']
            """,
        ).strErrors
        assertEquals(errors, ["[ERROR] persistent-workspaces: Contains duplicated workspace names"])
    }

    func testPersistentWorkspacesAreAvailableOnlySinceVersion2() {
        let errors = parseConfig(
            """
            persistent-workspaces = ['a']
            """,
        ).strErrors
        assertEquals(errors, ["[ERROR] persistent-workspaces: This config option is only available since \'config-version = 2\'"])
    }

    func testWrongTypeForCommand() {
        let errors = parseConfig(
            """
            [mode.main.binding]
                alt-a = [1, 'focus right']
            """,
        ).strErrors
        assertEquals(errors, ["[ERROR] mode.main.binding.alt-a[0]: Expected type is \'String\'. But actual type is \'Int\'"])
    }

    func testDropBindings() {
        let result = parseConfig(
            """
            mode.main = {}
            """,
        )
        assertTrue(result.allowReloadConfig)
        assertEquals(result.errors, [])
        assertTrue(result.config.modes[mainModeId]?.bindings.isEmpty == true)
    }

    func testParseMode() {
        let result = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
            """,
        )
        assertEquals(result.errors, [])
        let binding = HotkeyBinding(.option, .h, .cmd(FocusCommand.new(direction: .left)))
        assertEquals(
            result.config.modes[mainModeId],
            Mode(bindings: [binding.descriptionWithKeyCode: binding]),
        )
    }

    func testModesMustContainDefaultModeError() {
        let result = parseConfig(
            """
            [mode.foo.binding]
                alt-h = 'focus left'
            """,
        )
        assertEquals(
            result.strErrors,
            ["[ERROR] mode: Please specify \'main\' mode"],
        )
        assertEquals(result.config.modes[mainModeId], nil)
    }

    func testHotkeyParseError() {
        let result = parseConfig(
            """
            [mode.main.binding]
                alt-hh = 'focus left'
                aalt-j = 'focus down'
                alt-k = 'focus up'
            """,
        )
        assertEquals(
            result.strErrors,
            [
                "[ERROR] mode.main.binding.aalt-j: Can\'t parse modifiers in \'aalt-j\' binding",
                "[ERROR] mode.main.binding.alt-hh: Can\'t parse the key in \'alt-hh\' binding",
            ],
        )
        let binding = HotkeyBinding(.option, .k, .cmd(FocusCommand.new(direction: .up)))
        assertEquals(
            result.config.modes[mainModeId],
            Mode(bindings: [binding.descriptionWithKeyCode: binding]),
        )
    }

    func testPermanentWorkspaceNames() {
        let result = parseConfig(
            """
            [mode.main.binding]
                alt-1 = 'workspace 1'
                alt-2 = 'workspace 2'
                alt-3 = ['workspace 3']
                alt-4 = ['workspace 4', 'focus left']
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.persistentWorkspaces.sorted(), ["1", "2", "3", "4"])
    }

    func testUnknownTopLevelKeyParseError() {
        let result = parseConfig(
            """
            unknownKey = true
            enable-normalization-flatten-containers = false
            """,
        )
        assertEquals(
            result.strErrors,
            ["[ERROR] unknownKey: Unknown top-level key"],
        )
        assertEquals(result.config.enableNormalizationFlattenContainers, false)
    }

    func testUnknownKeyParseError() {
        let result = parseConfig(
            """
            enable-normalization-flatten-containers = false
            [gaps]
                unknownKey = true
            """,
        )
        assertEquals(
            result.strErrors,
            ["[ERROR] gaps.unknownKey: Unknown key"],
        )
        assertEquals(result.config.enableNormalizationFlattenContainers, false)
    }

    func testTypeMismatch() {
        let errors = parseConfig(
            """
            enable-normalization-flatten-containers = 'true'
            """,
        ).strErrors
        assertEquals(
            errors,
            ["[ERROR] enable-normalization-flatten-containers: Expected type is \'Bool\'. But actual type is \'String\'"],
        )
    }

    func testConfigParseError() {
        assertFalse(parseConfig("true").allowReloadConfig)
        assertEquals(
            parseConfig("true").strErrors,
            ["[ERROR] (Line 1) Syntax error: missing =."],
        )

        assertEquals(
            parseConfig("\n1").strErrors,
            ["[ERROR] (Line 2) Syntax error: missing =."],
        )

        assertEquals(
            parseConfig("foo: 1").strErrors,
            ["[ERROR] (Line 1) Syntax error: missing =."],
        )

        assertEquals(
            parseConfig("foo = 1.0").strErrors,
            ["[ERROR] foo: Unsupported TOML type: Double"],
        )

        assertEquals(
            parseConfig("foo.bar = 1979-05-27").strErrors,
            ["[ERROR] foo.bar: Unsupported TOML type: LocalDate", "[ERROR] foo: Unknown top-level key"],
        )
    }

    func testMoveWorkspaceToMonitorCommandParsing() {
        XCTAssertTrue(parseCommand("move-workspace-to-monitor --wrap-around next").cmdOrNil?.flatten().singleOrNil() is MoveWorkspaceToMonitorCommand)
        XCTAssertTrue(parseCommand("move-workspace-to-display --wrap-around next").cmdOrNil?.flatten().singleOrNil() is MoveWorkspaceToMonitorCommand)
    }

    func testParseTiles() {
        let command = parseCommand("layout tiles h_tiles v_tiles list h_list v_list").cmdOrNil?.flatten().singleOrNil()
        XCTAssertTrue(command is LayoutCommand)
        assertEquals((command as! LayoutCommand).args.toggleBetween.val, [.tiles, .h_tiles, .v_tiles, .tiles, .h_tiles, .v_tiles])

        guard case .help = parseCommand("layout tiles -h") else {
            XCTFail()
            return
        }
    }

    func testSplitCommandAndFlattenContainersNormalization() {
        let errors = parseConfig(
            """
            enable-normalization-flatten-containers = true
            [mode.main.binding]
            [mode.foo.binding]
                alt-s = 'split horizontal'
            """,
        ).strErrors
        let expected = """
            [ERROR] The config contains:
            1. usage of 'split' command
            2. enable-normalization-flatten-containers = true
            These two settings don't play nicely together. 'split' command has no effect when enable-normalization-flatten-containers is disabled.

            My recommendation: keep the normalizations enabled, and prefer 'join-with' over 'split'.
            """
        assertEquals(errors, [expected])
    }

    func testParseWorkspaceToMonitorAssignment() {
        let result = parseConfig(
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
            result.config.workspaceToMonitorForceAssignment,
            [
                "workspace_name_1": [.sequenceNumber(1)],
                "workspace_name_2": [.main],
                "workspace_name_3": [.secondary],
                "workspace_name_4": [.pattern("built-in")!],
                "workspace_name_5": [.pattern("^built-in retina display$")!],
                "workspace_name_6": [.secondary, .sequenceNumber(1)],
                "workspace_name_x": [.sequenceNumber(2)],
                "7": [.pattern("foo")!],
                "w7": [.main],
                "w8": [],
            ],
        )
        assertEquals([
            "[ERROR] workspace-to-monitor-force-assignment.w7[0]: Empty string is an illegal monitor description",
            "[ERROR] workspace-to-monitor-force-assignment.w8: Monitor sequence numbers uses 1-based indexing. Values less than 1 are illegal",
        ], result.strErrors)
        assertEquals([:], defaultConfig.workspaceToMonitorForceAssignment)
    }

    func testParseOnWindowDetected() {
        let result = parseConfig(
            """
            on-window-detected = [
                { # 0
                    if = 'true',
                    check-further-callbacks = true,
                    run = ['layout floating', 'move-node-to-workspace W'],
                },
                { # 1
                    if.app-id = 'com.apple.systempreferences',
                    run = [],
                },
                {}, # 2
                { # 3
                    if = 'true', run = ['move-node-to-workspace S', 'layout tiling'],
                },
                { # 4
                    if = 'true', run = ['move-node-to-workspace S', 'move-node-to-workspace W'],
                },
                { # 5
                    if = 'true', run = ['move-node-to-workspace S', 'layout h_tiles'],
                },
                { # 6
                    if = 'test %{app-bundle-id} = org.alacritty',
                    run = ['move-node-to-workspace T'],
                },
                { if = '', run = ''}, # 7
            ]
            """,
        )
        let matcher6Args = TestCmdArgs(rawArgs: [])
            .copy(\.lhs, .initialized(.app(.appBundleId)))
            .copy(\.infixOperator, .initialized(.equals))
            .copy(\.rhs, .initialized("org.alacritty"))
        assertEquals(result.config.onWindowDetected, [
            WindowDetectedCallback( // 0
                matcher: .command(.cmd(TrueCommand.instance)),
                checkFurtherCallbacks: true,
                rawRun: .seq([
                    .cmd(LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.floating]))),
                    .cmd(MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "W"))),
                ]),
            ),
            WindowDetectedCallback( // 1
                matcher: .legacy(LegacyWindowDetectedCallbackMatcher(
                    appId: "com.apple.systempreferences",
                )),
                rawRun: .empty,
            ),
            WindowDetectedCallback( // 3
                matcher: .command(.cmd(TrueCommand.instance)),
                rawRun: .seq([
                    .cmd(MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "S"))),
                    .cmd(LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.tiling]))),
                ]),
            ),
            WindowDetectedCallback( // 4
                matcher: .command(.cmd(TrueCommand.instance)),
                rawRun: .seq([
                    .cmd(MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "S"))),
                    .cmd(MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "W"))),
                ]),
            ),
            WindowDetectedCallback( // 5
                matcher: .command(.cmd(TrueCommand.instance)),
                rawRun: .seq([
                    .cmd(MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "S"))),
                    .cmd(LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.h_tiles]))),
                ]),
            ),
            WindowDetectedCallback( // 6
                matcher: .command(.cmd(TestCommand(args: matcher6Args))),
                rawRun: .cmd(MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "T"))),
            ),
        ])

        assertEquals(result.strErrors, [
            "[ERROR] on-window-detected[2]: Omitting \'if\' is error prone. You can use `if = \'true\'` to preserve the previous behavior.\nBut heads up! You may have missed \'check-further-callbacks = true\'",
            "[ERROR] on-window-detected[2]: \'run\' is mandatory key",
            "[ERROR] on-window-detected[7]: Omitting \'if\' is error prone. You can use `if = \'true\'` to preserve the previous behavior.\nBut heads up! You may have missed \'check-further-callbacks = true\'",
        ])
    }

    func testParseOnWindowDetected2() {
        let result = parseConfig(
            """
            on-window-detected = [
                { check-further-callbacks = true, run = '', },
            ]
            """,
        )
        assertEquals(result.config.onWindowDetected, [
            WindowDetectedCallback(
                matcher: .command(.empty),
                checkFurtherCallbacks: true,
                rawRun: .empty,
            ),
        ])

        assertEquals(result.errors, [])
    }

    func testParseInlineTables() {
        let errors = parseConfig(
            """
            on-window-detected = [
                {
                    check-further-callbacks = true,
                    run = ['layout floating', 'move-node-to-workspace W'],
                },
                {
                    if.app-id = 'com.apple.systempreferences',
                    run = [],
                }
            ]
            """,
        ).errors
        assertEquals(errors, [])
    }

    func testTomlParser() {
        // https://github.com/nikitabobko/AeroSpace/issues/1064
        let errors = parseConfig(
            """
            [[[on-window-detected]]
            if.app-id = 'com.apple.findmy'
            run = 'layout floating'

            [on-window-detected]]
            if.app-id = 'com.openai.chat'
            run = 'layout floating'
            """,
        ).strErrors
        assertEquals(errors, ["[ERROR] (Line 1) Syntax error: invalid or missing key."])
    }

    func testParseOnWindowDetectedRegex() {
        let result = parseConfig(
            """
            [[on-window-detected]]
                if.app-name-regex-substring = '^system settings$'
                run = []
            """,
        )
        let expected = WindowDetectedCallbackMatcher.legacy(LegacyWindowDetectedCallbackMatcher(appNameRegexSubstring: .new("^system settings$").getOrDie()))
        assertEquals(result.config.onWindowDetected.singleOrNil()!.matcher, expected)
        assertEquals(result.errors, [])
    }

    func testRegex() {
        var devNull: [String] = []
        XCTAssertTrue("System Settings".contains(caseInsensitiveRegex: CaseInsensitiveRegex.new("settings").getOrNil(appendErrorTo: &devNull)!))
        XCTAssertTrue(!"System Settings".contains(caseInsensitiveRegex: CaseInsensitiveRegex.new("^settings^").getOrNil(appendErrorTo: &devNull)!))
    }

    func testParseGaps() {
        let result1 = parseConfig(
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
        assertEquals(result1.errors, [])
        assertEquals(
            result1.config.gaps,
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
                            PerMonitorValue(description: .pattern("built-in")!, value: 3),
                            PerMonitorValue(description: .secondary, value: 4),
                        ],
                        default: 6,
                    ),
                    right: .perMonitor([PerMonitorValue(description: .sequenceNumber(2), value: 7)], default: 8),
                ),
            ),
        )

        let result2 = parseConfig(
            """
            [gaps]
                inner.horizontal = [true]
                inner.vertical = [{ foo.main = 1 }, { monitor = { foo = 2, bar = 3 } }, 1]
            """,
        )
        assertEquals(result2.strErrors, [
            "[ERROR] gaps.inner.horizontal: The last item in the array must be of type Int",
            "[ERROR] gaps.inner.vertical[0]: The table is expected to have a single key \'monitor\'",
            "[ERROR] gaps.inner.vertical[1].monitor: The table is expected to have a single key",
        ])
    }

    func testAfterLoginCommandDeprecation() {
        let result = parseConfig(
            """
            after-login-command = ['exec-and-forget echo hi']
            """,
        )
        assertEquals(
            result.strErrors,
            ["[ERROR] after-login-command: after-login-command is deprecated since AeroSpace 0.19.0. https://github.com/nikitabobko/AeroSpace/issues/1482"],
        )

        // Empty array is still accepted
        let okResult = parseConfig(
            """
            after-login-command = []
            """,
        )
        assertEquals(okResult.errors, [])
    }

    func testOnFocusChangedAsSingleStringAndAsList() {
        let result = parseConfig(
            """
            on-focus-changed = 'focus left'
            on-mode-changed = ['focus right', 'focus up']
            on-focused-monitor-changed = 'focus down'
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.onFocusChanged.flatten().count, 1)
        XCTAssertTrue(result.config.onFocusChanged.flatten()[0] is FocusCommand)
        assertEquals(result.config.onModeChanged.flatten().count, 2)
        assertEquals(result.config.onFocusedMonitorChanged.flatten().count, 1)
    }

    func testOnFocusChangedTypeError() {
        let result = parseConfig(
            """
            on-focus-changed = 1
            """,
        )
        assertEquals(
            result.strErrors,
            ["[ERROR] on-focus-changed: Expected types are \'string\' or \'array\'. But actual type is \'int\'"],
        )
    }

    func testParseDefaultRootContainerLayout() {
        let result = parseConfig(
            """
            default-root-container-layout = 'accordion'
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.defaultRootContainerLayout, .accordion)

        let listResult = parseConfig(
            """
            default-root-container-layout = 'list'
            """,
        )
        assertEquals(listResult.errors, [])
        assertEquals(listResult.config.defaultRootContainerLayout, .tiles)

        let bad = parseConfig(
            """
            default-root-container-layout = 'bogus'
            """,
        )
        assertEquals(
            bad.strErrors,
            ["[ERROR] default-root-container-layout: Can\'t parse layout \'bogus\'"],
        )
    }

    func testParseDefaultRootContainerOrientation() {
        let result = parseConfig(
            """
            default-root-container-orientation = 'vertical'
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.defaultRootContainerOrientation, .vertical)

        let bad = parseConfig(
            """
            default-root-container-orientation = 'diagonal'
            """,
        )
        assertEquals(
            bad.strErrors,
            ["[ERROR] default-root-container-orientation: Can\'t parse default container orientation \'diagonal\'"],
        )
    }

    func testDeprecatedIndentForNestedContainers() {
        let errors = parseConfig(
            """
            indent-for-nested-containers-with-the-same-orientation = 30
            """,
        ).strErrors
        assertEquals(
            errors,
            ["[ERROR] indent-for-nested-containers-with-the-same-orientation: Deprecated. Please drop it from the config. See https://github.com/nikitabobko/AeroSpace/issues/96"],
        )
    }

    func testDeprecatedNonEmptyWorkspacesRootContainersLayoutOnStartup() {
        // The 'smart' value used to be accepted and is silently dropped now
        let smart = parseConfig(
            """
            non-empty-workspaces-root-containers-layout-on-startup = 'smart'
            """,
        )
        assertEquals(smart.errors, [])

        let bad = parseConfig(
            """
            non-empty-workspaces-root-containers-layout-on-startup = 'tiles'
            """,
        ).strErrors
        assertEquals(
            bad,
            ["[ERROR] non-empty-workspaces-root-containers-layout-on-startup: \'non-empty-workspaces-root-containers-layout-on-startup\' is deprecated. Please drop it from your config"],
        )
    }

    func testOutdatedConfigVersionWarning() {
        let result = parseConfig(
            """
            config-version = 1
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.warnings.count, 1)
        XCTAssertTrue(result.warnings[0].message.contains("'config-version = 1' is outdated"))

        // config-version = 2 (the current max) should not produce the outdated warning
        let v2 = parseConfig(
            """
            config-version = 2
            """,
        )
        assertEquals(v2.errors, [])
        assertEquals(v2.warnings, [])
    }

    func testTopLevelTypeIsNotTable() {
        // TOML arrays at the root parse as a key error, but values returning a non-table json hit the
        // preventConfigReload path. Use a doubled array-of-tables header to trigger TOML syntax failure
        // and confirm that an unparsable TOML is flagged as preventing reload.
        let result = parseConfig("a = ")
        assertFalse(result.allowReloadConfig)
    }

    func testParseKeyMapping() {
        let result = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
                q = 'q'
                unicorn = 'u'

            [mode.main.binding]
                alt-unicorn = 'workspace wonderland'
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.keyMapping, KeyMapping(preset: .qwerty, rawKeyNotationToKeyCode: [
            "q": .q,
            "unicorn": .u,
        ]))
        let binding = HotkeyBinding(.option, .u, .cmd(WorkspaceCommand(args: WorkspaceCmdArgs(target: .direct(.parse("unicorn").getOrDie())))))
        assertEquals(result.config.modes[mainModeId]?.bindings, [binding.descriptionWithKeyCode: binding])

        let errors1 = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
                q = 'qw'
                ' f' = 'f'
            """,
        ).strErrors
        assertEquals(errors1, [
            "[ERROR] key-mapping.key-notation-to-key-code: ' f' is invalid key notation",
            "[ERROR] key-mapping.key-notation-to-key-code.q: 'qw' is invalid key code",
        ])

        let dvorakResult = parseConfig(
            """
            key-mapping.preset = 'dvorak'
            """,
        )
        assertEquals(dvorakResult.errors, [])
        assertEquals(dvorakResult.config.keyMapping, KeyMapping(preset: .dvorak, rawKeyNotationToKeyCode: [:]))
        assertEquals(dvorakResult.config.keyMapping.resolve()["quote"], .q)
        let colemakResult = parseConfig(
            """
            key-mapping.preset = 'colemak'
            """,
        )
        assertEquals(colemakResult.errors, [])
        assertEquals(colemakResult.config.keyMapping, KeyMapping(preset: .colemak, rawKeyNotationToKeyCode: [:]))
        assertEquals(colemakResult.config.keyMapping.resolve()["f"], .e)
    }
}

extension ParseConfigResult {
    var strErrors: [String] {
        errors.map { $0.description(.error) }
    }

    var strWarnings: [String] {
        warnings.map { $0.description(.warning) }
    }
}
