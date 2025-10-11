public struct ListExecEnvVarsCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listExecEnvVars,
        allowInConfig: true,
        help: list_exec_env_vars_help_generated,
        flags: [:],
        posArgs: [],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
