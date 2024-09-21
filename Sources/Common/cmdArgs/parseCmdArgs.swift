public func parseCmdArgs(_ args: [String]) -> ParsedCmd<any CmdArgs> {
    let subcommand = String(args.first ?? "")
    if subcommand.isEmpty {
        return .failure("Can't parse empty string command")
    }
    if let subcommandParser: any SubCommandParserProtocol = subcommandParsers[subcommand] {
        return subcommandParser.parse(args: Array(args.dropFirst()))
    } else {
        return .failure("Unrecognized subcommand '\(subcommand)'")
    }
}

public protocol CmdArgs: Copyable, Equatable, CustomStringConvertible, AeroAny {
    static var parser: CmdParser<Self> { get }
    var rawArgs: EquatableNoop<[String]> { get } // Non Equatable because test comparion

    // Two very common flags among commands
    var windowId: UInt32? { get set }
    var workspaceName: WorkspaceName? { get set }
}

public extension CmdArgs {
    static var info: CmdStaticInfo { Self.parser.info }

    func equals(_ other: any CmdArgs) -> Bool { // My brain is cursed with Java
        (other as? Self).flatMap { self == $0 } ?? false
    }

    var description: String {
        switch Self.info.kind {
            case .execAndForget:
                CmdKind.execAndForget.rawValue + " " + (self as! ExecAndForgetCmdArgs).bashScript
            default:
                ([Self.info.kind.rawValue] + rawArgs.value).joinArgs()
        }
    }
}

public struct CmdParser<T: Copyable> {
    let info: CmdStaticInfo
    let options: [String: any ArgParserProtocol<T>]
    let arguments: [any ArgParserProtocol<T>]
}

public func cmdParser<T>(
    kind: CmdKind,
    allowInConfig: Bool,
    help: String,
    options: [String: any ArgParserProtocol<T>],
    arguments: [any ArgParserProtocol<T>]
) -> CmdParser<T> {
    CmdParser(
        info: CmdStaticInfo(help: help, kind: kind, allowInConfig: allowInConfig),
        options: options,
        arguments: arguments
    )
}

public struct CmdStaticInfo: Equatable {
    public let help: String
    public let kind: CmdKind
    public let allowInConfig: Bool // Query commands are prohibited in config

    public init(
        help: String,
        kind: CmdKind,
        allowInConfig: Bool
    ) {
        self.help = help
        self.kind = kind
        self.allowInConfig = allowInConfig
    }
}

func noArgsParser<T: Copyable>(_ kind: CmdKind, allowInConfig: Bool) -> CmdParser<T> {
    cmdParser(
        kind: kind,
        allowInConfig: allowInConfig,
        help: """
            USAGE: \(kind.rawValue) [-h|--help]
            """,
        options: [:],
        arguments: []
    )
}
