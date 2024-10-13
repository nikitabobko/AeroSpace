public struct ListAppsCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listApps,
        allowInConfig: false,
        help: list_apps_help_generated,
        options: [
            "--macos-native-hidden": boolFlag(\.macosHidden),

            // Formatting flags
            "--format": ArgParser(\._format, parseFormat),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        arguments: [],
        conflictingOptions: [
            ["--format", "--count"],
            ["--json", "--count"],
        ]
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var macosHidden: Bool?
    public var _format: [StringInterToken] = []
    public var outputOnlyCount: Bool = false
    public var json: Bool = false
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

public func parseListAppsCmdArgs(_ args: [String]) -> ParsedCmd<ListAppsCmdArgs> {
    parseSpecificCmdArgs(ListAppsCmdArgs(rawArgs: args), args)
        .flatMap { if $0.json, let msg = getErrorIfFormatIsIncompatibleWithJson($0._format) { .failure(msg) } else { .cmd($0) } }
}

func getErrorIfFormatIsIncompatibleWithJson(_ format: [StringInterToken]) -> String? {
    for x in format {
        switch x {
            case .value("right-padding"):
                return "%{right-padding} interpolation variable is not allowed when --json is used"
            case .value: break // skip
            case .literal(let literal):
                if literal.contains(where: { $0 != " " }) {
                    return "Only interpolation variables and spaces are allowed in '--format' when '--json' is used"
                }
        }
    }
    return nil
}
