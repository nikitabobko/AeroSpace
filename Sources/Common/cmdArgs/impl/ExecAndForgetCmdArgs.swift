public struct ExecAndForgetCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .execAndForget,
        allowInConfig: true,
        help: exec_and_forget_help_generated,
        flags: [:],
        posArgs: [],
    )

    public init(bashScript: String) {
        self.commonState = .init([bashScript])
        self.bashScript = bashScript
    }

    public let bashScript: String
}
