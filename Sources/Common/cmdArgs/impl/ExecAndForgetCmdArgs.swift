public struct ExecAndForgetCmdArgs: CmdArgs {
    public var rawArgsForStrRepr: EquatableNoop<StrArrSlice> { .init([bashScript]) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .execAndForget,
        allowInConfig: true,
        help: exec_and_forget_help_generated,
        flags: [:],
        posArgs: [],
    )

    public init(bashScript: String) {
        self.bashScript = bashScript
    }

    public let bashScript: String
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
