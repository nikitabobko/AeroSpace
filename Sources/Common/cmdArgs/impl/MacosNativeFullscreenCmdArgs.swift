public struct MacosNativeFullscreenCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .macosNativeFullscreen,
        allowInConfig: true,
        help: macos_native_fullscreen_help_generated,
        options: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--window-id": optionalWindowIdFlag(),
        ],
        arguments: [ArgParser(\.toggle, parseToggleEnum)]
    )

    public var toggle: ToggleEnum = .toggle
    public var failIfNoop: Bool = false
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}

public func parseMacosNativeFullscreenCmdArgs(_ args: [String]) -> ParsedCmd<MacosNativeFullscreenCmdArgs> {
    parseSpecificCmdArgs(MacosNativeFullscreenCmdArgs(rawArgs: args), args)
        .filter("--fail-if-noop requires 'on' or 'off' argument") { $0.failIfNoop.implies($0.toggle == .on || $0.toggle == .off) }
}

public enum ToggleEnum: Sendable {
    case on, off, toggle
}

func parseToggleEnum(arg: String, nextArgs: inout [String]) -> Parsed<ToggleEnum> {
    return switch arg {
        case "on": .success(.on)
        case "off": .success(.off)
        default: .failure("Can't parse '\(arg)'. Possible values: on|off")
    }
}
