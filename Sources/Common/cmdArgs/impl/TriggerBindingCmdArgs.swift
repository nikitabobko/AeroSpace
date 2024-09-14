public struct TriggerBindingCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .triggerBinding,
        allowInConfig: true,
        help: """
            USAGE: trigger-binding [-h|--help] <binding> --mode <mode-id>

            OPTIONS:
              -h, --help         Print help
              --mode <mode-id>   Mode to search <binding> in

            ARGUMENTS:
              <binding>          Binding to trigger
            """,
        options: [
            "--mode": singleValueOption(\._mode, "<mode-id>") { $0 },
        ],
        arguments: [newArgParser(\.binding, { arg, _ in .success(arg) }, mandatoryArgPlaceholder: "<binding>")]
    )

    public var _mode: String? = nil
    public var binding: Lateinit<String> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: String?
}

public extension TriggerBindingCmdArgs {
    var mode: String { _mode! }
}

public func parseTriggerBindingCmdArgs(_ args: [String]) -> ParsedCmd<TriggerBindingCmdArgs> {
    parseRawCmdArgs(TriggerBindingCmdArgs(rawArgs: .init(args)), args)
        .filter("--mode flag is mandatory") { $0._mode != nil }
}
