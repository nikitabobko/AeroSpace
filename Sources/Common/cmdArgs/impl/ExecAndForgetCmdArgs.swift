public struct ExecAndForgetCmdArgs: CmdArgs {
    public var rawArgs: EquatableNoop<[String]> { .init([bashScript]) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .execAndForget,
        allowInConfig: true,
        help: exec_and_forget_help_generated,
        options: [:],
        arguments: []
    )

    public init(bashScript: String) {
        self.bashScript = bashScript
    }

    public let bashScript: String
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
