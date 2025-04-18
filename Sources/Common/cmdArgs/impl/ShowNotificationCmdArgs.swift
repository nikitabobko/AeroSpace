public struct ShowNotificationCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .showNotification,
        allowInConfig: true,
        help: show_notifiaction_help_generated,
        options: [:],
        arguments: [
            newArgParser(\.title, { arg, _ in .success(arg) }, mandatoryArgPlaceholder: "<title>"),
            newArgParser(\.body, { arg, _ in .success(arg) }, mandatoryArgPlaceholder: "<body>"),
        ]
    )

    public /*conforms*/ var windowId: UInt32?
    public /*conforms*/ var workspaceName: WorkspaceName?
    public var title: Lateinit<String> = .uninitialized
    public var body: Lateinit<String> = .uninitialized
}
