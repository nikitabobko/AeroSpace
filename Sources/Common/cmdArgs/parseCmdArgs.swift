public func parseCmdArgs(_ args: StrArrSlice) -> ParsedCmd<any CmdArgs> {
    let subcommand = String(args.first ?? "")
    if subcommand.isEmpty {
        return .failure("Can't parse empty string command")
    }
    if let subcommandParser: any SubCommandParserProtocol = subcommandParsers[subcommand] {
        return subcommandParser.parse(args: args.slice(1...).orDie())
    } else {
        return .failure("Unrecognized subcommand '\(subcommand)'")
    }
}

public protocol CmdArgs: ConvenienceCopyable, Equatable, CustomStringConvertible, AeroAny, Sendable {
    static var parser: CmdParser<Self> { get }
    var rawArgsForStrRepr: EquatableNoop<StrArrSlice> { get }

    // Two very common flags among commands
    var windowId: UInt32? { get set }
    var workspaceName: WorkspaceName? { get set }
}

extension CmdArgs {
    public static var info: CmdStaticInfo { Self.parser.info }

    public func equals(_ other: any CmdArgs) -> Bool { // My brain is cursed with Java
        (other as? Self).flatMap { self == $0 } ?? false
    }

    public var description: String {
        switch Self.info.kind {
            case .execAndForget:
                CmdKind.execAndForget.rawValue + " " + (self as! ExecAndForgetCmdArgs).bashScript
            default:
                ([Self.info.kind.rawValue] + rawArgsForStrRepr.value.toArray()).joinArgs()
        }
    }
}

public struct CmdParser<T: ConvenienceCopyable>: Sendable {
    let info: CmdStaticInfo
    let flags: [String: any SubArgParserProtocol<T>]
    let positionalArgs: [any ArgParserProtocol<T>]
    let conflictingOptions: [Set<String>]
}

public func cmdParser<T>(
    kind: CmdKind,
    allowInConfig: Bool,
    help: String,
    flags: [String: any SubArgParserProtocol<T>],
    posArgs: [any ArgParserProtocol<T>],
    conflictingOptions: [Set<String>] = [],
) -> CmdParser<T> {
    CmdParser(
        info: CmdStaticInfo(help: help, kind: kind, allowInConfig: allowInConfig),
        flags: flags,
        positionalArgs: posArgs,
        conflictingOptions: conflictingOptions,
    )
}

public struct CmdStaticInfo: Equatable, Sendable {
    public let help: String
    public let kind: CmdKind
    public let allowInConfig: Bool // Query commands are prohibited in config

    public init(
        help: String,
        kind: CmdKind,
        allowInConfig: Bool,
    ) {
        self.help = help
        self.kind = kind
        self.allowInConfig = allowInConfig
    }
}
