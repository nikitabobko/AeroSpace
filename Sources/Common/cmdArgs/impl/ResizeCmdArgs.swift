public struct ResizeCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .resize,
        allowInConfig: true,
        help: resize_help_generated,
        options: [
            "--window-id": optionalWindowIdFlag(),
        ],
        arguments: [
            newArgParser(\.dimension, parseDimension, mandatoryArgPlaceholder: "(smart|smart-opposite|width|height)"),
            newArgParser(\.units, parseUnits, mandatoryArgPlaceholder: "[+|-]<number>"),
        ]
    )

    public var dimension: Lateinit<ResizeCmdArgs.Dimension> = .uninitialized
    public var units: Lateinit<ResizeCmdArgs.Units> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public init(
        rawArgs: [String],
        dimension: Dimension,
        units: Units
    ) {
        self.rawArgs = .init(rawArgs)
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

public func parseResizeCmdArgs(_ args: [String]) -> ParsedCmd<ResizeCmdArgs> {
    parseSpecificCmdArgs(ResizeCmdArgs(rawArgs: args), args)
}

private func parseDimension(arg: String, nextArgs: inout [String]) -> Parsed<ResizeCmdArgs.Dimension> {
    parseEnum(arg, ResizeCmdArgs.Dimension.self)
}

private func parseUnits(arg: String, nextArgs: inout [String]) -> Parsed<ResizeCmdArgs.Units> {
    if let number = UInt(arg.removePrefix("+").removePrefix("-")) {
        switch () {
            case _ where arg.starts(with: "+"): .success(.add(number))
            case _ where arg.starts(with: "-"): .success(.subtract(number))
            default: .success(.set(number))
        }
    } else {
        .failure("<number> argument must be a number")
    }
}
