public struct ModeCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .mode,
        allowInConfig: true,
        help: """
            USAGE: mode [-h|--help] <binding-mode>
            """,
        options: [:],
        arguments: [newArgParser(\.targetMode, parseTargetMode, mandatoryArgPlaceholder: "<binding-mode>")]
    )

    public var targetMode: Lateinit<String> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}

private func parseTargetMode(arg: String, nextArgs: inout [String]) -> Parsed<String> {
    .success(arg)
}
