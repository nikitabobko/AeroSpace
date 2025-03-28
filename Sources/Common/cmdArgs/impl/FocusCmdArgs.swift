private let boundar = "<boundary>"
private let actio = "<action>"

public struct FocusCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .focus,
        allowInConfig: true,
        help: focus_help_generated,
        options: [
            "--ignore-floating": falseBoolFlag(\.floatingAsTiling),
            "--boundaries": ArgParser(\.rawBoundaries, upcastArgParserFun(parseBoundaries)),
            "--boundaries-action": ArgParser(\.rawBoundariesAction, upcastArgParserFun(parseBoundariesAction)),
            "--window-id": ArgParser(\.windowId, upcastArgParserFun(parseArgWithUInt32)),
            "--dfs-index": ArgParser(\.dfsIndex, upcastArgParserFun(parseArgWithUInt32)),
        ],
        arguments: [ArgParser(\.targetArg, upcastArgParserFun(parseFocusTargetArg))]
    )

    public var rawBoundaries: Boundaries? = nil // todo cover boundaries wrapping with tests
    public var rawBoundariesAction: WhenBoundariesCrossed? = nil
    public var dfsIndex: UInt32? = nil
    public var targetArg: FocusTargetArg? = nil
    public var floatingAsTiling: Bool = true
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], targetArg: FocusTargetArg) {
        self.rawArgs = .init(rawArgs)
        self.targetArg = targetArg
    }

    public init(rawArgs: [String], windowId: UInt32) {
        self.rawArgs = .init(rawArgs)
        self.windowId = windowId
    }

    public init(rawArgs: [String], dfsIndex: UInt32) {
        self.rawArgs = .init(rawArgs)
        self.dfsIndex = dfsIndex
    }

    public enum Boundaries: String, CaseIterable, Equatable, Sendable {
        case workspace
        case allMonitorsUnionFrame = "all-monitors-outer-frame"
    }
    public enum WhenBoundariesCrossed: String, CaseIterable, Equatable, Sendable {
        case stop = "stop"
        case fail = "fail"
        case wrapAroundTheWorkspace = "wrap-around-the-workspace"
        case wrapAroundAllMonitors = "wrap-around-all-monitors"
    }
}

// Subset of FocusCmdTarget that is passed as a positional argument.
public enum FocusTargetArg: Equatable, Sendable {
    case direction(CardinalDirection)
    case dfsRelative(NextPrev)
}

func parseFocusTargetArg(_ arg: String, _ nextArgs: inout [String]) -> Parsed<FocusTargetArg> {
    return switch arg {
        case "left": .success(.direction(.left))
        case "down": .success(.direction(.down))
        case "up": .success(.direction(.up))
        case "right": .success(.direction(.right))
        case "dfs-next": .success(.dfsRelative(.next))
        case "dfs-prev": .success(.dfsRelative(.prev))
        default: .failure("Can't parse '\(arg)\'. Possible values: left|down|up|right|dfs-next|dfs-prev")
    }
}

public enum FocusCmdTarget {
    case direction(CardinalDirection)
    case windowId(UInt32)
    case dfsIndex(UInt32)
    case dfsRelative(NextPrev)

    var isDfsRelative: Bool {
        if case .dfsRelative = self {
            return true
        } else {
            return false
        }
    }
}

public extension FocusCmdArgs {
    var target: FocusCmdTarget {
        if let targetArg {
            return switch targetArg {
                case .direction(let dir): .direction(dir)
                case .dfsRelative(let nextPrev): .dfsRelative(nextPrev)
            }
        }
        if let windowId {
            return .windowId(windowId)
        }
        if let dfsIndex {
            return .dfsIndex(dfsIndex)
        }
        error("Parser invariants are broken")
    }

    var boundaries: Boundaries { rawBoundaries ?? .workspace }
    var boundariesAction: WhenBoundariesCrossed { rawBoundariesAction ?? .stop }
}

public func parseFocusCmdArgs(_ args: [String]) -> ParsedCmd<FocusCmdArgs> {
    return parseSpecificCmdArgs(FocusCmdArgs(rawArgs: args), args)
        .flatMap { (raw: FocusCmdArgs) -> ParsedCmd<FocusCmdArgs> in
            raw.boundaries == .workspace && raw.boundariesAction == .wrapAroundAllMonitors
                ? .failure("\(raw.boundaries.rawValue) and \(raw.boundariesAction.rawValue) is an invalid combination of values")
                : .cmd(raw)
        }
        .filter("Mandatory argument is missing. (left|down|up|right|dfs-next|dfs-prev), --window-id or --dfs-index is required") {
            $0.targetArg != nil || $0.windowId != nil || $0.dfsIndex != nil
        }
        .filter("--window-id is incompatible with other options") {
            $0.windowId == nil || $0 == FocusCmdArgs(rawArgs: args, windowId: $0.windowId!)
        }
        .filter("--dfs-index is incompatible with other options") {
            $0.dfsIndex == nil || $0 == FocusCmdArgs(rawArgs: args, dfsIndex: $0.dfsIndex!)
        }
        .filter("(dfs-next|dfs-prev) only supports --boundaries workspace") {
            !$0.target.isDfsRelative || $0.boundaries == .workspace
        }
}

private func parseBoundariesAction(arg: String, nextArgs: inout [String]) -> Parsed<FocusCmdArgs.WhenBoundariesCrossed> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return parseEnum(arg, FocusCmdArgs.WhenBoundariesCrossed.self)
    } else {
        return .failure("\(actio) is mandatory")
    }
}

private func parseBoundaries(arg: String, nextArgs: inout [String]) -> Parsed<FocusCmdArgs.Boundaries> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return parseEnum(arg, FocusCmdArgs.Boundaries.self)
    } else {
        return .failure("\(boundar) is mandatory")
    }
}
