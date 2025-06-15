public struct ListExecEnvVarsCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listExecEnvVars,
        allowInConfig: true,
        help: list_exec_env_vars_help_generated,
        options: [:],
        arguments: [],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
