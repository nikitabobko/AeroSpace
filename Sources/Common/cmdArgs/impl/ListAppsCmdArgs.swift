public struct ListAppsCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listApps,
        allowInConfig: false,
        help: list_apps_help_generated,
        options: [
            "--macos-native-hidden": boolFlag(\.macosHidden),
            "--format": ArgParser(\._format, parseFormat),
            "--count": trueBoolFlag(\.outputOnlyCount),
        ],
        arguments: [],
        conflictingOptions: [
            ["--format", "--count"],
        ]
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var macosHidden: Bool?
    public var _format: [StringInterToken] = []
    public var outputOnlyCount: Bool = false
}

public extension ListAppsCmdArgs {
    var format: [StringInterToken] {
        _format.isEmpty
            ? [
                .value("app-pid"), .value("right-padding"), .literal(" | "),
                .value("app-bundle-id"), .value("right-padding"), .literal(" | "),
                .value("app-name"),
            ]
            : _format
    }
}
