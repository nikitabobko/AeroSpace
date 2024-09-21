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
        arguments: [ArgParser(\.direction, upcastArgParserFun(parseCardinalDirectionArg))]
    )

    public var rawBoundaries: Boundaries? = nil // todo cover boundaries wrapping with tests
    public var rawBoundariesAction: WhenBoundariesCrossed? = nil
    public var dfsIndex: UInt32? = nil
    public var direction: CardinalDirection? = nil
    public var floatingAsTiling: Bool = true
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], direction: CardinalDirection) {
        self.rawArgs = .init(rawArgs)
        self.direction = direction
    }

    public init(rawArgs: [String], windowId: UInt32) {
        self.rawArgs = .init(rawArgs)
        self.windowId = windowId
    }

    public init(rawArgs: [String], dfsIndex: UInt32) {
        self.rawArgs = .init(rawArgs)
        self.dfsIndex = dfsIndex
    }

    public enum Boundaries: String, CaseIterable, Equatable {
        case workspace
        case allMonitorsUnionFrame = "all-monitors-outer-frame"
    }
    public enum WhenBoundariesCrossed: String, CaseIterable, Equatable {
        case stop = "stop"
        case wrapAroundTheWorkspace = "wrap-around-the-workspace"
        case wrapAroundAllMonitors = "wrap-around-all-monitors"
    }
}

public enum FocusCmdTarget {
    case direction(CardinalDirection)
    case windowId(UInt32)
    case dfsIndex(UInt32)
}

public extension FocusCmdArgs {
    var target: FocusCmdTarget {
        if let direction {
            return .direction(direction)
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
        .filter("Mandatory argument is missing. '\(CardinalDirection.unionLiteral)', --window-id or --dfs-index is required") {
            $0.direction != nil || $0.windowId != nil || $0.dfsIndex != nil
        }
        .filter("--window-id is incompatible with other options") {
            $0.windowId == nil || $0 == FocusCmdArgs(rawArgs: args, windowId: $0.windowId!)
        }
        .filter("--dfs-index is incompatible with other options") {
            $0.dfsIndex == nil || $0 == FocusCmdArgs(rawArgs: args, dfsIndex: $0.dfsIndex!)
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
