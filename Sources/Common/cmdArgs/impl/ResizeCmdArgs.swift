public struct ResizeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .resize,
        help: resize_help_generated,
        flags: [
            "--window-id": windowIdSubArgParser(),
        ],
        posArgs: [
            newMandatoryPosArgParser(\.dimension, parseDimension, placeholder: "(smart|smart-opposite|width|height|split-left|split-right|split-up|split-down)"),
            newMandatoryPosArgParser(\.units, parseUnits, placeholder: "[+|-]<number>"),
        ],
    )

    public var dimension: Lateinit<ResizeCmdArgs.Dimension> = .uninitialized
    public var units: Lateinit<ResizeCmdArgs.Units> = .uninitialized

    public init(
        rawArgs: [String],
        dimension: Dimension,
        units: Units,
    ) {
        self.commonState = .init(rawArgs.slice)
        self.dimension = .initialized(dimension)
        self.units = .initialized(units)
    }

    public enum Dimension: String, CaseIterable, Equatable, Sendable {
        case width, height, smart
        case smartOpposite = "smart-opposite"
        case splitLeft = "split-left"
        case splitRight = "split-right"
        case splitUp = "split-up"
        case splitDown = "split-down"

        /// The direction to move the split to. `nil` for the dimensions that resize the window itself
        public var splitDirection: CardinalDirection? {
            switch self {
                case .splitLeft: .left
                case .splitRight: .right
                case .splitUp: .up
                case .splitDown: .down
                case .width, .height, .smart, .smartOpposite: nil
            }
        }
    }

    public enum Units: Equatable, Sendable {
        case set(UInt)
        case add(UInt)
        case subtract(UInt)
    }
}

func parseResizeCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ResizeCmdArgs> {
    parseSpecificCmdArgs(ResizeCmdArgs(rawArgs: args), args)
}

private func parseDimension(i: PosArgParserInput) -> ParsedCliArgs<ResizeCmdArgs.Dimension> {
    .init(parseEnum(i.arg, ResizeCmdArgs.Dimension.self), advanceBy: 1)
}

private func parseUnits(i: PosArgParserInput) -> ParsedCliArgs<ResizeCmdArgs.Units> {
    if let number = UInt(i.arg.removePrefix("+").removePrefix("-")) {
        switch true {
            case i.arg.starts(with: "+"): .succ(.add(number), advanceBy: 1)
            case i.arg.starts(with: "-"): .succ(.subtract(number), advanceBy: 1)
            default: .succ(.set(number), advanceBy: 1)
        }
    } else {
        .fail("<number> argument must be a number", advanceBy: 1)
    }
}
