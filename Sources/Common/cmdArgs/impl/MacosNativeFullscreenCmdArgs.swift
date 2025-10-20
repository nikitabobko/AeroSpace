public struct MacosNativeFullscreenCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .macosNativeFullscreen,
        allowInConfig: true,
        help: macos_native_fullscreen_help_generated,
        flags: [
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [ArgParser(\.toggle, parseToggleEnum)],
    )

    public var toggle: ToggleEnum = .toggle
    public var failIfNoop: Bool = false
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}

public func parseMacosNativeFullscreenCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MacosNativeFullscreenCmdArgs> {
    parseSpecificCmdArgs(MacosNativeFullscreenCmdArgs(rawArgs: args), args)
        .filter("--fail-if-noop requires 'on' or 'off' argument") { $0.failIfNoop.implies($0.toggle == .on || $0.toggle == .off) }
}

public enum ToggleEnum: Sendable {
    case on, off, toggle
}

func parseToggleEnum(i: ArgParserInput) -> ParsedCliArgs<ToggleEnum> {
    switch i.arg {
        case "on": .succ(.on, advanceBy: 1)
        case "off": .succ(.off, advanceBy: 1)
        default: .fail("Can't parse '\(i.arg)'. Possible values: on|off", advanceBy: 1)
    }
}
