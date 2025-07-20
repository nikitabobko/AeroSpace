public struct TriggerBindingCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .triggerBinding,
        allowInConfig: true,
        help: trigger_binding_help_generated,
        options: [
            "--mode": singleValueOption(\._mode, "<mode-id>") { $0 },
        ],
        arguments: [newArgParser(\.binding, { arg, _ in .success(arg) }, mandatoryArgPlaceholder: "<binding>")],
    )

    public var _mode: String? = nil
    public var binding: Lateinit<String> = .uninitialized
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}

extension TriggerBindingCmdArgs {
    public var mode: String { _mode.orDie() }
}

public func parseTriggerBindingCmdArgs(_ args: [String]) -> ParsedCmd<TriggerBindingCmdArgs> {
    parseSpecificCmdArgs(TriggerBindingCmdArgs(rawArgs: .init(args)), args)
        .filter("--mode flag is mandatory") { $0._mode != nil }
}
