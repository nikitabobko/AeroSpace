public struct ExecAndForgetCmdArgs: CmdArgs {
    public let bashScript: String
    public static let info: CmdStaticInfo = CmdStaticInfo(
        help: "USAGE: exec-and-forget <bash-script>",
        kind: .execAndForget,
        allowInConfig: true
    )

    public init(bashScript: String) {
        self.bashScript = bashScript
    }
}
