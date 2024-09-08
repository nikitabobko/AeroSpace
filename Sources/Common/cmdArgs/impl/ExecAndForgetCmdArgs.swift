public struct ExecAndForgetCmdArgs: CmdArgs {
    public var rawArgs: EquatableNoop<[String]> { .init([bashScript]) }
    public static let info: CmdStaticInfo = CmdStaticInfo(
        help: "USAGE: exec-and-forget <bash-script>",
        kind: .execAndForget,
        allowInConfig: true
    )

    public init(bashScript: String) {
        self.bashScript = bashScript
    }

    public let bashScript: String
    public var windowId: UInt32?
    public var workspaceName: String?
}
