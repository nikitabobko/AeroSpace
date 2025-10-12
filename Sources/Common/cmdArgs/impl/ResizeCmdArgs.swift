public struct ResizeCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    fileprivate init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .resize,
        allowInConfig: true,
        help: resize_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [
            newArgParser(\.dimension, parseDimension, mandatoryArgPlaceholder: "(smart|smart-opposite|width|height)"),
            newArgParser(\.units, parseUnits, mandatoryArgPlaceholder: "[+|-]<number>"),
        ],
    )

    public var dimension: Lateinit<ResizeCmdArgs.Dimension> = .uninitialized
    public var units: Lateinit<ResizeCmdArgs.Units> = .uninitialized
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public init(
        rawArgs: [String],
        dimension: Dimension,
        units: Units,
    ) {
        self.rawArgsForStrRepr = .init(rawArgs.slice)
        self.dimension = .initialized(dimension)
        self.units = .initialized(units)
    }

    public enum Dimension: String, CaseIterable, Equatable, Sendable {
        case width, height, smart
        case smartOpposite = "smart-opposite"
    }

    public enum Units: Equatable, Sendable {
        case set(UInt)
        case add(UInt)
        case subtract(UInt)
    }
}

public func parseResizeCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ResizeCmdArgs> {
    parseSpecificCmdArgs(ResizeCmdArgs(rawArgs: args), args)
}

private func parseDimension(i: ArgParserInput) -> ParsedCliArgs<ResizeCmdArgs.Dimension> {
    .init(parseEnum(i.arg, ResizeCmdArgs.Dimension.self), advanceBy: 1)
}

private func parseUnits(i: ArgParserInput) -> ParsedCliArgs<ResizeCmdArgs.Units> {
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
