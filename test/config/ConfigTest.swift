import XCTest
import Nimble
@testable import AeroSpace_Debug
import Common

final class ConfigTest: XCTestCase {
    func testParseI3Config() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/i3-like-config-example.toml"))
        let (i3Config, errors) = parseConfig(toml)
        XCTAssertEqual(errors.descriptions, [])
        XCTAssertEqual(i3Config.enableNormalizationFlattenContainers, false)
        XCTAssertEqual(i3Config.enableNormalizationOppositeOrientationForNestedContainers, false)
    }

    func testParseDefaultConfig() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/default-config.toml"))
        let (_, errors) = parseConfig(toml)
        XCTAssertEqual(errors.descriptions, [])
    }

    func testQueryCantBeUsedInConfig() {
        let (_, errors) = parseConfig(
            """
            [mode.main.binding]
            alt-a = 'list-apps'
            """
        )
        XCTAssertTrue(errors.descriptions.singleOrNil()?.contains("cannot be used in config") == true)
    }

    func testDropBindings() {
        let (config, errors) = parseConfig(
            """
            mode.main = {}
            """
        )
        XCTAssertEqual(errors.descriptions, [])
        XCTAssertTrue(config.modes[mainModeId]?.bindings.isEmpty == true)
    }

    func testParseMode() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
            alt-h = 'focus left'
            """
        )
        XCTAssertEqual(errors.descriptions, [])
        let binding = HotkeyBinding(.option, .h, [FocusCommand.new(direction: .left)])
        XCTAssertEqual(
            config.modes[mainModeId],
            Mode(name: nil, bindings: [binding.binding: binding])
        )
    }

    func testModesMustContainDefaultModeError() {
        let (config, errors) = parseConfig(
            """
            [mode.foo.binding]
            alt-h = 'focus left'
            """
        )
        XCTAssertEqual(
            errors.descriptions,
            ["mode: Please specify \'main\' mode"]
        )
        XCTAssertEqual(config.modes[mainModeId], nil)
    }

    func testHotkeyParseError() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
            alt-hh = 'focus left'
            aalt-j = 'focus down'
            alt-k = 'focus up'
            """
        )
        XCTAssertEqual(
            errors.descriptions,
            ["mode.main.binding.aalt-j: Can\'t parse modifiers in \'aalt-j\' binding",
             "mode.main.binding.alt-hh: Can\'t parse the key in \'alt-hh\' binding"]
        )
        let binding = HotkeyBinding(.option, .k, [FocusCommand.new(direction: .up)])
        XCTAssertEqual(
            config.modes[mainModeId],
            Mode(name: nil, bindings: [binding.binding: binding])
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
            """
        )
        XCTAssertEqual(errors.descriptions, [])
        XCTAssertEqual(config.preservedWorkspaceNames.sorted(), ["1", "2", "3", "4"])
    }

    func testUnknownKeyParseError() {
        let (config, errors) = parseConfig(
            """
            unknownKey = true
            enable-normalization-flatten-containers = false
            """
        )
        XCTAssertEqual(
            errors.descriptions,
            ["unknownKey: Unknown key"]
        )
        XCTAssertEqual(config.enableNormalizationFlattenContainers, false)
    }

    func testTypeMismatch() {
        let (_, errors) = parseConfig(
            """
            enable-normalization-flatten-containers = 'true'
            """
        )
        XCTAssertEqual(
            errors.descriptions,
            ["enable-normalization-flatten-containers: Expected type is \'bool\'. But actual type is \'string\'"]
        )
    }

    func testTomlParseError() {
        let (_, errors) = parseConfig("true")
        XCTAssertEqual(
            errors.descriptions,
            ["Error while parsing key-value pair: encountered end-of-file (at line 1, column 5)"]
        )
    }

    func testMoveWorkspaceToMonitorCommandParsing() {
        XCTAssertTrue(parseCommand("move-workspace-to-monitor --wrap-around next").cmdOrNil is MoveWorkspaceToMonitorCommand)
        XCTAssertTrue(parseCommand("move-workspace-to-display --wrap-around next").cmdOrNil is MoveWorkspaceToMonitorCommand)
    }

    func testParseTiles() {
        let command = parseCommand("layout tiles h_tiles v_tiles list h_list v_list").cmdOrNil
        XCTAssertTrue(command is LayoutCommand)
        XCTAssertEqual((command as! LayoutCommand).args.toggleBetween.val, [.tiles, .h_tiles, .v_tiles, .tiles, .h_tiles, .v_tiles])

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
            """
        )
        XCTAssertEqual(
            ["""
             The config contains:
             1. usage of 'split' command
             2. enable-normalization-flatten-containers = true
             These two settings don't play nicely together. 'split' command has no effect in this case
             """],
            errors.descriptions
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
            """
        )
        XCTAssertEqual(
            parsed.workspaceToMonitorForceAssignment,
            [
                "workspace_name_1": [.sequenceNumber(1)],
                "workspace_name_2": [.main],
                "workspace_name_3": [.secondary],
                "workspace_name_4": [.pattern(try! Regex("built-in"))],
                "workspace_name_5": [.pattern(try! Regex("^built-in retina display$"))],
                "workspace_name_6": [.secondary, .sequenceNumber(1)],
                "workspace_name_x": [.sequenceNumber(2)],
                "7": [.pattern(try! Regex("foo"))],
                "w7": [.main],
                "w8": [],
            ]
        )
        XCTAssertEqual([
            "workspace-to-monitor-force-assignment.w7[0]: Empty string is an illegal monitor description",
            "workspace-to-monitor-force-assignment.w8: Monitor sequence numbers uses 1-based indexing. Values less than 1 are illegal"
        ], errors.descriptions)
        XCTAssertEqual([:], defaultConfig.workspaceToMonitorForceAssignment)
    }

    func testParseOnWindowDetected() {
        let (parsed, errors) = parseConfig(
            """
            [[on-window-detected]]
            check-further-callbacks = true
            run = ['layout floating', 'move-node-to-workspace W']

            [[on-window-detected]]
            if.app-id = 'com.apple.systempreferences'
            run = []

            [[on-window-detected]]

            [[on-window-detected]]
            run = ['move-node-to-workspace S', 'layout tiling']

            [[on-window-detected]]
            run = ['move-node-to-workspace S', 'move-node-to-workspace W']

            [[on-window-detected]]
            run = ['move-node-to-workspace S', 'layout h_tiles']
            """
        )
        XCTAssertEqual(parsed.onWindowDetected, [
            WindowDetectedCallback(
                matcher: CallbackMatcher(
                    appId: nil,
                    appNameRegexSubstring: nil,
                    windowTitleRegexSubstring: nil
                ),
                checkFurtherCallbacks: true,
                rawRun: [
                    LayoutCommand(args: LayoutCmdArgs(toggleBetween: [.floating])),
                    MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(.direct(WTarget.Direct("W"))))
                ]
            ),
            WindowDetectedCallback(
                matcher: CallbackMatcher(
                    appId: "com.apple.systempreferences",
                    appNameRegexSubstring: nil,
                    windowTitleRegexSubstring: nil
                ),
                checkFurtherCallbacks: false,
                rawRun: []
            ),
        ])

        XCTAssertEqual(errors.descriptions, [
            "on-window-detected[2]: \'run\' is mandatory key",
            "on-window-detected[3]: For now, \'move-node-to-workspace\' must be the latest instruction in the callback (otherwise it\'s error-prone). Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20",
            "on-window-detected[4]: For now, \'move-node-to-workspace\' can be mentioned only once in \'run\' callback. Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20",
            "on-window-detected[5]: For now, \'layout floating\', \'layout tiling\' and \'mode-node-to-workspace\' are the only commands that are supported in \'on-window-detected\'. Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20",
            "on-window-detected[5]: For now, \'move-node-to-workspace\' must be the latest instruction in the callback (otherwise it\'s error-prone). Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20"
        ])
    }

    func testParseOnWindowDetectedRegex() {
        let (config, errors) = parseConfig(
            """
            [[on-window-detected]]
            if.app-name-regex-substring = '^system settings$'
            run = []
            """
        )
        XCTAssertTrue(config.onWindowDetected.singleOrNil()!.matcher.appNameRegexSubstring != nil)
        XCTAssertEqual(errors.descriptions, [])
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
            """
        )
        XCTAssertEqual(errors1.descriptions, [])
        XCTAssertEqual(
            config.gaps,
            Gaps(
                inner: .init(
                    vertical: .perMonitor([(description: .main, value: 1), (description: .secondary, value: 2)], default: 5),
                    horizontal: .constant(10)
                ),
                outer: .init(
                    left: .constant(12),
                    bottom: .constant(13),
                    top: .perMonitor([(description: .pattern(try! .init("built-in")), value: 3), (description: .secondary, value: 4)], default: 6),
                    right: .perMonitor([(description: .sequenceNumber(2), value: 7)], default: 8)
                )
            )
        )

        let (_, errors2) = parseConfig(
            """
            [gaps]
            inner.horizontal = [true]
            inner.vertical = [{ foo.main = 1 }, { monitor = { foo = 2, bar = 3 } }, 1]
            """
        )
        XCTAssertEqual(errors2.descriptions, [
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
            alt-unicorn = 'workspace unicorn'
            """
        )
        XCTAssertEqual(errors.descriptions, [])
        XCTAssertEqual(config.keyMapping, KeyMapping(preset: .qwerty, rawKeyNotationToKeyCode: [
            "q": .q,
            "unicorn": .u,
        ]))
        let binding = HotkeyBinding(.option, .u, [WorkspaceCommand(args: WorkspaceCmdArgs(.direct(WTarget.Direct("unicorn"))))])
        XCTAssertEqual(config.modes[mainModeId]?.bindings, [binding.binding: binding])

        let (_, errors1) = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
            q = 'qw'
            ' f' = 'f'
            """
        )
        expect(errors1.descriptions).to(equal([
            "key-mapping.key-notation-to-key-code: ' f' is invalid key notation",
            "key-mapping.key-notation-to-key-code.q: 'qw' is invalid key code"
        ]))

        let (dvorakConfig, dvorakErrors) = parseConfig(
            """
            key-mapping.preset = 'dvorak'
            """
        )
        XCTAssertEqual(dvorakErrors.descriptions, [])
        XCTAssertEqual(dvorakConfig.keyMapping, KeyMapping(preset: .dvorak, rawKeyNotationToKeyCode: [:]))
        expect(dvorakConfig.keyMapping.resolve()["quote"]).to(equal(.q))
    }
}
