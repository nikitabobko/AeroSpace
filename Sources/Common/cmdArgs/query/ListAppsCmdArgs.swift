public struct ListAppsCmdArgs: RawCmdArgs, CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listApps,
        allowInConfig: false,
        help: """
            USAGE: list-apps [-h|--help] [--macos-native-hidden [no]]

            OPTIONS:
              -h, --help                  Print help
              --macos-native-hidden [no]  Filter results to only print hidden applications.
                                          [no] inverts the condition
            """,
        options: [
            "--macos-native-hidden": boolFlag(\.macosHidden),
        ],
        arguments: []
    )

    public var macosHidden: Bool?
}
