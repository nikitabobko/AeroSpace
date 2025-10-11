public struct ModeCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .mode,
        allowInConfig: true,
        help: mode_help_generated,
        flags: [:],
        posArgs: [newArgParser(\.targetMode, parseTargetMode, mandatoryArgPlaceholder: "<binding-mode>")],
    )

    public var targetMode: Lateinit<String> = .uninitialized
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}

private func parseTargetMode(arg: String, nextArgs: inout [String]) -> Parsed<String> {
    .success(arg)
}
