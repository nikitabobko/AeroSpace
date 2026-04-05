public struct TestCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .test,
        allowInConfig: false,
        help: test_help_generated,
        flags: [
            // Design question: Does --window-id flag compare window ids or checks the conditions against the specified window?
            // Design question: Does --workspace flag compare workspaces or checks the conditions against the specified workspace?
            "--act-on-window-id": windowIdSubArgParser(),
            "--act-on-workspace": workspaceSubArgParser(),

            "--app-id": singleValueSubArgParser(\.appBundleId, "<app-bundle-id>", Result.success),

            "--app-name-regex-substring": singleValueSubArgParser(\.appNameRegexSubstring, "<case-insensitive-regex>", CaseInsensitiveRegex.new),
            "--window-title-regex-substring": singleValueSubArgParser(\.windowTitleRegexSubstring, "<case-insensitive-regex>", CaseInsensitiveRegex.new),
            "--workspace-matches": singleValueSubArgParser(\.workspacePredicate, "<workspace>", WorkspaceName.parse),
            "--window-id-matches": singleValueSubArgParser(\.windowIdPredicate, "<window-id>", parseUInt32),
            "--is-during-aerospace-startup": boolFlag(\.duringAeroSpaceStartup),
        ],
        posArgs: [],
    )
    public typealias ExitCodeType = TestCommandExitCode

    public var workspacePredicate: WorkspaceName? = nil
    public var duringAeroSpaceStartup: Bool? = nil

    public var appBundleId: String? = nil
    public var appNameRegexSubstring: CaseInsensitiveRegex? = nil
    public var windowTitleRegexSubstring: CaseInsensitiveRegex? = nil
    public var windowIdPredicate: UInt32? = nil
}

public enum TestCommandExitCode: RawRepresentable, ExitCode {
    case _true
    case _false
    case fail

    public init?(rawValue: Int32) {
        switch rawValue {
            case EXIT_CODE_ZERO: self = ._true
            case EXIT_CODE_ONE: self = ._false
            case EXIT_CODE_TWO: self = .fail
            default: return nil
        }
    }

    public var rawValue: Int32 {
        switch self {
            case ._true: EXIT_CODE_ZERO
            case ._false: EXIT_CODE_ONE
            case .fail: EXIT_CODE_TWO
        }
    }
}
