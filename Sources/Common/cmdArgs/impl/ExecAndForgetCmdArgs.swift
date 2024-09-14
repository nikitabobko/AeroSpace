public struct ExecAndForgetCmdArgs: CmdArgs {
    public var rawArgs: EquatableNoop<[String]> { .init([bashScript]) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .execAndForget,
        allowInConfig: true,
        help: "USAGE: exec-and-forget <bash-script>",
        options: [:],
        arguments: []
    )

    public init(bashScript: String) {
        self.bashScript = bashScript
    }

    public let bashScript: String
    public var windowId: UInt32?
    public var workspaceName: String?
}
