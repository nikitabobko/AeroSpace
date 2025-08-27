public struct SleepCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .sleep,
        allowInConfig: true,
        help: sleep_help_generated,
        options: [:],
        arguments: [newArgParser(\.milliseconds, { arg, _ in 
            guard let milliseconds = UInt32(arg) else {
                return .failure("Can't parse milliseconds '\(arg)'. Must be a positive integer.")
            }
            return .success(milliseconds)
        }, mandatoryArgPlaceholder: "<milliseconds>")],
    )

    public var milliseconds: Lateinit<UInt32> = .uninitialized
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
