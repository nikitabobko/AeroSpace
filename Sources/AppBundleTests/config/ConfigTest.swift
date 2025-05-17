@testable import AppBundle
import Common
import XCTest

@MainActor
final class ConfigTest: XCTestCase {
    func testParseI3Config() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/i3-like-config-example.toml"))
        let (i3Config, errors) = parseConfig(toml)
        assertEquals(errors, [])
        assertEquals(i3Config.execConfig, defaultConfig.execConfig)
        assertEquals(i3Config.enableNormalizationFlattenContainers, false)
        assertEquals(i3Config.enableNormalizationOppositeOrientationForNestedContainers, false)
    }

    func testParseDefaultConfig() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/default-config.toml"))
        let (_, errors) = parseConfig(toml)
        assertEquals(errors, [])
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
        assertEquals(errors, [])
        XCTAssertTrue(config.modes[mainModeId]?.bindings.isEmpty == true)
    }

    func testParseMode() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
            """
        )
        assertEquals(errors, [])
        let binding = HotkeyBinding(
            specificModifiers: [PhysicalModifierKey.leftOption],
            keyCode: VirtualKeyCodes.h,
            commands: [FocusCommand.new(direction: .left)],
            "alt-h"
        )
        assertEquals(
            config.modes[mainModeId],
            Mode(name: nil, bindings: [binding.descriptionWithKeyCode: binding])
        )
    }

    func testModesMustContainDefaultModeError() {
        let (config, errors) = parseConfig(
            """
            [mode.foo.binding]
                alt-h = 'focus left'
            """
        )
        assertEquals(
            errors.descriptions,
            ["mode: Please specify \'main\' mode"]
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
            """
        )
        assertEquals(
            errors.descriptions,
            [
                "mode.main.binding.aalt-j: Can't parse modifier token 'aalt' in 'aalt-j' binding. Available: \(specificModifiersMap.keys.joined(separator: ", "))",
                "mode.main.binding.alt-hh: Can't parse the key 'hh' in 'alt-hh' binding. Available keys: \(keyNotationToVirtualKeyCode.keys.sorted().joined(separator: ", "))",
            ].sorted()
        )
        let binding = HotkeyBinding(
            specificModifiers: [PhysicalModifierKey.leftOption],
            keyCode: VirtualKeyCodes.k,
            commands: [FocusCommand.new(direction: .up)],
            "alt-k"
        )
        assertEquals(
            config.modes[mainModeId],
            Mode(name: nil, bindings: [binding.descriptionWithKeyCode: binding])
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
        assertEquals(errors.descriptions, [])
        assertEquals(config.preservedWorkspaceNames.sorted(), ["1", "2", "3", "4"])
    }

    func testUnknownKeyParseError() {
        let (config, errors) = parseConfig(
            """
            unknownKey = true
            enable-normalization-flatten-containers = false
            """
        )
        assertEquals(
            errors.descriptions,
            ["unknownKey: Unknown key"]
        )
        assertEquals(config.enableNormalizationFlattenContainers, false)
    }

    func testTypeMismatch() {
        let (_, errors) = parseConfig(
            """
            enable-normalization-flatten-containers = 'true'
            """
        )
        assertEquals(
            errors.descriptions,
            ["enable-normalization-flatten-containers: Expected type is \'bool\'. But actual type is \'string\'"]
        )
    }

    func testTomlParseError() {
        let (_, errors) = parseConfig("true")
        assertEquals(
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
            """
        )
        assertEquals(
            ["""
                The config contains:
                1. usage of 'split' command
                2. enable-normalization-flatten-containers = true
                These two settings don't play nicely together. 'split' command has no effect when enable-normalization-flatten-containers is disabled.

                My recommendation: keep the normalizations enabled, and prefer 'join-with' over 'split'.
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
        assertEquals(
            parsed.workspaceToMonitorForceAssignment,
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
            ]
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
        assertEquals(parsed.onWindowDetected, [
            WindowDetectedCallback(
                matcher: WindowDetectedCallbackMatcher(
                    appId: nil,
                    appNameRegexSubstring: nil,
                    windowTitleRegexSubstring: nil
                ),
                checkFurtherCallbacks: true,
                rawRun: [
                    LayoutCommand(args: LayoutCmdArgs(rawArgs: [], toggleBetween: [.floating])),
                    MoveNodeToWorkspaceCommand(args: MoveNodeToWorkspaceCmdArgs(workspace: "W")),
                ]
            ),
            WindowDetectedCallback(
                matcher: WindowDetectedCallbackMatcher(
                    appId: "com.apple.systempreferences",
                    appNameRegexSubstring: nil,
                    windowTitleRegexSubstring: nil
                ),
                checkFurtherCallbacks: false,
                rawRun: []
            ),
        ])

        assertEquals(errors.descriptions, [
            "on-window-detected[2]: \'run\' is mandatory key",
            "on-window-detected[3]: For now, \'move-node-to-workspace\' must be the latest instruction in the callback (otherwise it\'s error-prone). Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20",
            "on-window-detected[4]: For now, \'move-node-to-workspace\' can be mentioned only once in \'run\' callback. Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20",
            "on-window-detected[5]: For now, \'layout floating\', \'layout tiling\' and \'move-node-to-workspace\' are the only commands that are supported in \'on-window-detected\'. Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20",
            "on-window-detected[5]: For now, \'move-node-to-workspace\' must be the latest instruction in the callback (otherwise it\'s error-prone). Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20",
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
            """
        )
        assertEquals(errors1, [])
        assertEquals(
            config.gaps,
            Gaps(
                inner: .init(
                    vertical: .perMonitor(
                        [PerMonitorValue(description: .main, value: 1), PerMonitorValue(description: .secondary, value: 2)],
                        default: 5
                    ),
                    horizontal: .constant(10)
                ),
                outer: .init(
                    left: .constant(12),
                    bottom: .constant(13),
                    top: .perMonitor(
                        [
                            PerMonitorValue(description: .pattern("built-in")!, value: 3),
                            PerMonitorValue(description: .secondary, value: 4),
                        ],
                        default: 6
                    ),
                    right: .perMonitor([PerMonitorValue(description: .sequenceNumber(2), value: 7)], default: 8)
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
        assertEquals(errors2.descriptions, [
            "gaps.inner.horizontal: The last item in the array must be of type Int",
            "gaps.inner.vertical[0]: The table is expected to have a single key \'monitor\'",
            "gaps.inner.vertical[1].monitor: The table is expected to have a single key",
        ])
    }

    func testParseKeyMapping() {
        var errors: [TomlParseError] = []
        let config = parseKeyMapping(
            """
            preset = "qwerty"
            [key-notation-to-key-code]
            q = "a"
            unicorn = "u"
            """, .root, &errors
        )
        assertEquals(errors.descriptions, [])
        assertEquals(config, KeyMapping(preset: .qwerty, rawKeyNotationToVirtualKeyCode: [
            "q": VirtualKeyCodes.a,
            "unicorn": VirtualKeyCodes.u,
        ]))

        let binding = HotkeyBinding(
            specificModifiers: [PhysicalModifierKey.leftOption],
            keyCode: VirtualKeyCodes.u,
            commands: [WorkspaceCommand(args: WorkspaceCmdArgs(target: .direct(.parse("unicorn").getOrDie())))],
            "alt-u"
        )
        assertEquals(binding.descriptionWithKeyCode, "lalt-u")
        assertEquals(binding.descriptionWithKeyNotation, "alt-u")
    }

    func testParseKeyMappingLayoutPresets() {
        let (qwertyConfig, qwertyErrors) = parseConfig(
            """
            [key-mapping]
            preset = "qwerty"
            """
        )
        assertEquals(qwertyErrors.descriptions, [])
        assertEquals(qwertyConfig.keyMapping, KeyMapping(preset: .qwerty, rawKeyNotationToVirtualKeyCode: [:]))
        assertEquals(qwertyConfig.keyMapping.resolve()["q"], VirtualKeyCodes.q)

        let (dvorakConfig, dvorakErrors) = parseConfig(
            """
            [key-mapping]
            preset = "dvorak"
            """
        )
        assertEquals(dvorakErrors.descriptions, [])
        assertEquals(dvorakConfig.keyMapping, KeyMapping(preset: .dvorak, rawKeyNotationToVirtualKeyCode: [:]))
        assertEquals(dvorakConfig.keyMapping.resolve()["quote"], VirtualKeyCodes.q)

        let (colemakConfig, colemakErrors) = parseConfig(
            """
            [key-mapping]
            preset = "colemak"
            """
        )
        assertEquals(colemakErrors.descriptions, [])
        assertEquals(colemakConfig.keyMapping, KeyMapping(preset: .colemak, rawKeyNotationToVirtualKeyCode: [:]))
        assertEquals(colemakConfig.keyMapping.resolve()["f"], VirtualKeyCodes.e)
    }

    func testParseSpecificModifiers() {
        let toml = """
            [mode.main.binding]
                lalt-a = 'command1'
                ralt-b = 'command2'
                fn-f1 = 'command3'
                lcmd-rshift-c = 'command4'
                lctrl-lshift-ralt-d = 'command5'
            """
        let (config, errors) = parseConfig(toml)
        assertEquals(errors.descriptions, [])

        let bindings = config.modes[mainModeId]?.bindings
        XCTAssertNotNil(bindings)

        // Helper to check a binding
        func checkBinding(
            _ notation: String,
            _ expectedModifiers: Set<PhysicalModifierKey>,
            _ expectedKeyCode: UInt16,
            _ expectedCommandStrings: [String] = [] // Now expects an array of command strings
        ) {
            let keyForMap = (expectedModifiers.isEmpty ? "" : expectedModifiers.toString() + "-") + virtualKeyCodeToString(expectedKeyCode)
            let binding = bindings?[keyForMap]
            XCTAssertNotNil(binding, "Binding not found for \(notation) (expected key: \(keyForMap))")
            assertEquals(binding?.specificModifiers, expectedModifiers, additionalMsg: "Modifiers mismatch for \(notation)")
            assertEquals(binding?.keyCode, expectedKeyCode, additionalMsg: "Key code mismatch for \(notation)")
            assertEquals(binding?.descriptionWithKeyNotation, notation, additionalMsg: "Notation string mismatch for \(notation)")

            if !expectedCommandStrings.isEmpty {
                let actualCommandDescriptions: [String] = binding?.commands.compactMap { ($0 as? any CmdArgs)?.description } ?? []
                assertEquals(actualCommandDescriptions, expectedCommandStrings, additionalMsg: "Command mismatch for \(notation)")
            }
        }

        checkBinding("lalt-a", [.leftOption], VirtualKeyCodes.a, ["command1"])
        checkBinding("ralt-b", [.rightOption], VirtualKeyCodes.b, ["command2"])
        checkBinding("fn-f1", [.function], VirtualKeyCodes.f1, ["command3"])
        checkBinding("lcmd-rshift-c", [.leftCommand, .rightShift], VirtualKeyCodes.c, ["command4"])
        checkBinding("lctrl-lshift-ralt-d", [.leftControl, .leftShift, .rightOption], VirtualKeyCodes.d, ["command5"])
    }
}
