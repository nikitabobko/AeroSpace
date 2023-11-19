import XCTest
@testable import AeroSpace_Debug

final class ConfigTest: XCTestCase {
    func testParseI3Config() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "config-examples/i3-like-config-example.toml"))
        let (i3Config, errors) = parseConfig(toml)
        XCTAssertEqual(errors.descriptions, [])
        XCTAssertEqual(i3Config.enableNormalizationFlattenContainers, false)
        XCTAssertEqual(i3Config.enableNormalizationOppositeOrientationForNestedContainers, false)
    }

    func testParseMode() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
            alt-h = 'focus left'
            """
        )
        XCTAssertEqual(errors.descriptions, [])
        XCTAssertEqual(
            config.modes[mainModeId],
            Mode(name: nil, bindings: [HotkeyBinding(.option, .h, [FocusCommand(direction: .left)])])
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
        XCTAssertEqual(
            config.modes[mainModeId],
            Mode(name: nil, bindings: [HotkeyBinding(.option, .k, [FocusCommand(direction: .up)])])
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
        XCTAssertEqual(config.preservedWorkspaceNames, ["1", "2", "3"])
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
        var devNull: [String] = []
        XCTAssertTrue(parseCommand("move-workspace-to-monitor next").getOrNil(appendErrorTo: &devNull) is MoveWorkspaceToMonitorCommand)
        XCTAssertTrue(parseCommand("move-workspace-to-display next").getOrNil(appendErrorTo: &devNull) is MoveWorkspaceToMonitorCommand)
    }

    func testParseTiles() {
        var devNull: [String] = []
        let command = parseCommand("layout tiles h_tiles v_tiles list h_list v_list").getOrNil(appendErrorTo: &devNull)
        XCTAssertTrue(command is LayoutCommand)
        XCTAssertEqual((command as! LayoutCommand).toggleBetween, [.tiles, .h_tiles, .v_tiles, .tiles, .h_tiles, .v_tiles])
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
            run = ['layout floating']

            [[on-window-detected]]
            app-id = 'com.apple.systempreferences'
            run = []

            [[on-window-detected]]
            """
        )
        XCTAssertEqual(parsed.onWindowDetected, [
            WindowDetectedCallback(
                appId: nil,
                appNameRegexSubstring: nil,
                windowTitleRegexSubstring: nil,
                run: [LayoutCommand(toggleBetween: [.floating])!]
            ),
            WindowDetectedCallback(
                appId: "com.apple.systempreferences",
                appNameRegexSubstring: nil,
                windowTitleRegexSubstring: nil,
                run: []
            )
        ])

        XCTAssertEqual(errors.descriptions, [
            "on-window-detected[2]: \'run\' is mandatory key"
        ])
    }

    func testParseOnWindowDetectedRegex() {
        let (config, errors) = parseConfig(
            """
            [[on-window-detected]]
            app-name-regex-substring = '^system settings$'
            run = []
            """
        )
        XCTAssertTrue(config.onWindowDetected.singleOrNil()!.appNameRegexSubstring != nil)
        XCTAssertEqual(errors.descriptions, [])
    }

    func testRegex() {
        var devNull: [String] = []
        XCTAssertTrue("System Settings".contains(parseCaseInsensitiveRegex("settings").getOrNil(appendErrorTo: &devNull)!))
        XCTAssertTrue(!"System Settings".contains(parseCaseInsensitiveRegex("^settings^").getOrNil(appendErrorTo: &devNull)!))
    }
}

extension MonitorDescription: Equatable {
    public static func ==(lhs: MonitorDescription, rhs: MonitorDescription) -> Bool {
        switch (lhs, rhs) {
        case (.sequenceNumber(let a), .sequenceNumber(let b)):
            return a == b
        case (.main, .main):
            return true
        case (.secondary, .secondary):
            return true
        case (.pattern, .pattern):
            return true
        default:
            return false
        }
    }
}

extension WindowDetectedCallback: Equatable {
    public static func ==(lhs: WindowDetectedCallback, rhs: WindowDetectedCallback) -> Bool {
        check(lhs.appNameRegexSubstring == nil &&
            lhs.windowTitleRegexSubstring == nil &&
            rhs.appNameRegexSubstring == nil &&
            rhs.windowTitleRegexSubstring == nil)
        return lhs.appId == rhs.appId &&
            lhs.run.map(\.describe) == rhs.run.map(\.describe)
    }
}

private extension [TomlParseError] {
    var descriptions: [String] { map(\.description) }
}

extension Mode: Equatable {
    public static func ==(lhs: Mode, rhs: Mode) -> Bool {
        lhs.name == rhs.name && lhs.bindings == rhs.bindings
    }
}

extension HotkeyBinding: Equatable {
    public static func ==(lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        lhs.modifiers == rhs.modifiers && lhs.key == rhs.key && lhs.commands.map(\.describe) == rhs.commands.map(\.describe)
    }
}

extension Command {
    var describe: CommandDescription {
        if let focus = self as? FocusCommand {
            return .focusCommand(focus.direction)
        } else if let resize = self as? ResizeCommand {
            return .resizeCommand(dimension: resize.dimension, mode: resize.mode, unit: resize.unit)
        } else if let layout = self as? LayoutCommand {
            return .layoutCommand(layout.toggleBetween)
        }
        error("Unsupported command: \(self)")
    }
}

enum CommandDescription: Equatable {
    case focusCommand(CardinalDirection)
    case resizeCommand(dimension: ResizeCommand.Dimension, mode: ResizeCommand.ResizeMode, unit: UInt)
    case layoutCommand([LayoutCommand.LayoutDescription])
}
