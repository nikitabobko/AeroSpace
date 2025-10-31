public struct TriggerBindingCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .triggerBinding,
        allowInConfig: true,
        help: trigger_binding_help_generated,
        flags: [
            "--mode": singleValueSubArgParser(\._mode, "<mode-id>") { $0 },
        ],
        posArgs: [newArgParser(\.binding, consumeStrCliArg, mandatoryArgPlaceholder: "<binding>")],
    )

    public var _mode: String? = nil
    public var binding: Lateinit<String> = .uninitialized
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}

extension TriggerBindingCmdArgs {
    public var mode: String { _mode.orDie() }
}

public func parseTriggerBindingCmdArgs(_ args: StrArrSlice) -> ParsedCmd<TriggerBindingCmdArgs> {
    parseSpecificCmdArgs(TriggerBindingCmdArgs(rawArgsForStrRepr: .init(args)), args)
        .filter("--mode flag is mandatory") { $0._mode != nil }
}
