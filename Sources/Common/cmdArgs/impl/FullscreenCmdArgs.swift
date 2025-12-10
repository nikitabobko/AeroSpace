public struct FullscreenCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .fullscreen,
        allowInConfig: true,
        help: fullscreen_help_generated,
        flags: [
            "--no-outer-gaps": trueBoolFlag(\.noOuterGaps),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [ArgParser(\.toggle, parseToggleEnum)],
    )

    public var toggle: ToggleEnum = .toggle
    public var noOuterGaps: Bool = false
    public var failIfNoop: Bool = false
}

public func parseFullscreenCmdArgs(_ args: StrArrSlice) -> ParsedCmd<FullscreenCmdArgs> {
    parseSpecificCmdArgs(FullscreenCmdArgs(rawArgs: args), args)
        .filterNot("--no-outer-gaps is incompatible with 'off' argument") { $0.toggle == .off && $0.noOuterGaps }
        .filter("--fail-if-noop requires 'on' or 'off' argument") { $0.failIfNoop.implies($0.toggle == .on || $0.toggle == .off) }
}
