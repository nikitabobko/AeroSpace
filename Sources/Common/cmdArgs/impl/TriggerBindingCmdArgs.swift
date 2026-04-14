public struct TriggerBindingCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .triggerBinding,
        allowInConfig: true,
        help: trigger_binding_help_generated,
        flags: [
            "--mode": singleValueSubArgParser(\._mode, "<mode-id>", Result.success),
        ],
        posArgs: [newMandatoryPosArgParser(\.binding, consumeStrCliArg, placeholder: "<binding>")],
    )
    public typealias ExitCodeType = Int32ExitCode

    public var _mode: String? = nil
    public var binding: Lateinit<String> = .uninitialized
}

extension TriggerBindingCmdArgs {
    public var mode: String { _mode.orDie() }
}

func parseTriggerBindingCmdArgs(_ args: StrArrSlice) -> ParsedCmd<TriggerBindingCmdArgs> {
    parseSpecificCmdArgs(TriggerBindingCmdArgs(rawArgs: args), args)
        .filter("--mode flag is mandatory") { $0._mode != nil }
}
