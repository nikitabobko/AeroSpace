private let boundar = "<boundary>"
private let actio = "<action>"

public struct FocusCmdArgs: CmdArgs, RawCmdArgs, Equatable, AeroAny {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .focus,
        allowInConfig: true,
        help: """
            USAGE: focus [<options>] \(CardinalDirection.unionLiteral)
               OR: focus [-h|--help] --window-id <window-id>

            OPTIONS:
              -h, --help                     Print help
              --window-id <window-id>        Focus window with specified <window-id>
              --boundaries \(boundar)        Defines focus boundaries.
                                             \(boundar) possible values: \(FocusCmdArgs.Boundaries.unionLiteral)
                                             The default is: \(FocusCmdArgs.Boundaries.workspace.rawValue)
              --boundaries-action \(actio)   Defines the behavior when requested to cross the \(boundar).
                                             \(actio) possible values: \(FocusCmdArgs.WhenBoundariesCrossed.unionLiteral)
                                             The default is: \(FocusCmdArgs.WhenBoundariesCrossed.wrapAroundTheWorkspace.rawValue)
              --ignore-floating              Don't perceive floating windows as part of the tree

            ARGUMENTS:
              (left|down|up|right)           Focus direction
            """,
        options: [
            "--ignore-floating": falseBoolFlag(\.floatingAsTiling),
            "--boundaries": ArgParser(\.rawBoundaries, upcastArgParserFun(parseBoundaries)),
            "--boundaries-action": ArgParser(\.rawBoundariesAction, upcastArgParserFun(parseBoundariesAction)),
            "--window-id": ArgParser(\.windowId, upcastArgParserFun(parseArgWithUInt32))
        ],
        arguments: [ArgParser(\.direction, upcastArgParserFun(parseCardinalDirectionArg))]
    )

    public var rawBoundaries: Boundaries? = nil // todo cover boundaries wrapping with tests
    public var rawBoundariesAction: WhenBoundariesCrossed? = nil
    public var windowId: UInt32? = nil
    public var direction: CardinalDirection? = nil
    public var floatingAsTiling: Bool = true

    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }

    public init(rawArgs: [String], direction: CardinalDirection) {
        self.rawArgs = .init(rawArgs)
        self.direction = direction
    }

    public init(rawArgs: [String], windowId: UInt32) {
        self.rawArgs = .init(rawArgs)
        self.windowId = windowId
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
}

public extension FocusCmdArgs {
    var target: FocusCmdTarget {
        if let direction {
            return .direction(direction)
        }
        if let windowId {
            return .windowId(windowId)
        }
        error("Parser invariants are broken")
    }

    var boundaries: Boundaries { rawBoundaries ?? .workspace }
    var boundariesAction: WhenBoundariesCrossed { rawBoundariesAction ?? .wrapAroundTheWorkspace }
}

public func parseFocusCmdArgs(_ args: [String]) -> ParsedCmd<FocusCmdArgs> {
    return parseRawCmdArgs(FocusCmdArgs(rawArgs: args), args)
        .flatMap { (raw: FocusCmdArgs) -> ParsedCmd<FocusCmdArgs> in
            raw.boundaries == .workspace && raw.boundariesAction == .wrapAroundAllMonitors
                ? .failure("\(raw.boundaries.rawValue) and \(raw.boundariesAction.rawValue) is an invalid combination of values")
                : .cmd(raw)
        }
        .filter("Mandatory argument is missing. '\(CardinalDirection.unionLiteral)' or --window-id") {
            $0.direction != nil || $0.windowId != nil
        }
        .filter("--window-id is incompatible with other options") {
            $0.windowId == nil || $0 == FocusCmdArgs(rawArgs: args, windowId: $0.windowId!)
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
