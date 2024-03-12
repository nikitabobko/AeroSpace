private let boundar = "<boundary>"
private let actio = "<action>"

public struct FocusCmdArgs: CmdArgs, RawCmdArgs, Equatable, AeroAny {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .focus,
        allowInConfig: true,
        help: """
              USAGE: focus [<OPTIONS>] \(CardinalDirection.unionLiteral)

              OPTIONS:
                -h, --help                     Print help
                --boundaries \(boundar)        Defines focus boundaries.
                                               \(boundar) possible values: \(FocusCmdArgs.Boundaries.unionLiteral)
                                               The default is: \(FocusCmdArgs.Boundaries.workspace.rawValue)
                --boundaries-action \(actio)   Defines the behavior when requested to cross the \(boundar).
                                               \(actio) possible values: \(FocusCmdArgs.WhenBoundariesCrossed.unionLiteral)
                                               The default is: \(FocusCmdArgs.WhenBoundariesCrossed.wrapAroundTheWorkspace.rawValue)

              ARGUMENTS:
                (left|down|up|right)           Focus direction
              """, // todo focus [OPTIONS] window-id <id>
        // ARGUMENTS:
        //  <id>                                  ID of window to focus
        options: [
            "--boundaries": ArgParser(\.boundaries, parseBoundaries),
            "--boundaries-action": ArgParser(\.boundariesAction, parseBoundariesAction)
        ],
        arguments: [newArgParser(\.direction, parseCardinalDirectionArg, mandatoryArgPlaceholder: CardinalDirection.unionLiteral)]
    )

    public var boundaries: Boundaries = .workspace // todo cover boundaries wrapping with tests
    public var boundariesAction: WhenBoundariesCrossed = .wrapAroundTheWorkspace
    public var direction: Lateinit<CardinalDirection> = .uninitialized

    fileprivate init() {}

    public init(direction: CardinalDirection) {
        self.direction = .initialized(direction)
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

public func parseFocusCmdArgs(_ args: [String]) -> ParsedCmd<FocusCmdArgs> {
    parseRawCmdArgs(FocusCmdArgs(), args)
        .flatMap { raw in
            if raw.boundaries == .workspace && raw.boundariesAction == .wrapAroundAllMonitors {
                return .failure("\(raw.boundaries.rawValue) and \(raw.boundariesAction.rawValue) is an invalid combination of values")
            }
            return .cmd(raw)
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
