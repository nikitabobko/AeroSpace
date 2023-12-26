public struct ResizeCmdArgs: RawCmdArgs, Equatable {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .resize,
        allowInConfig: true,
        help: """
              USAGE: resize [-h|--help] (smart|width|height) [+|-]<number>

              OPTIONS:
                -h, --help             Print help

              ARGUMENTS:
                (smart|width|height)   Dimension to resize
                <number>               Number
              """,
        options: [:],
        arguments: [
            newArgParser(\.dimension, parseDimension, mandatoryArgPlaceholder: "(smart|width|height)"),
            newArgParser(\.units, parseUnits, mandatoryArgPlaceholder: "[+|-]<number>"),
        ]
    )

    public var dimension: Lateinit<ResizeCmdArgs.Dimension> = .uninitialized
    public var units: Lateinit<ResizeCmdArgs.Units> = .uninitialized

    public init(
        dimension: Dimension,
        units: Units
    ) {
        self.dimension = .initialized(dimension)
        self.units = .initialized(units)
    }

    fileprivate init() {}

    public enum Dimension: String, CaseIterable, Equatable {
        case width, height, smart
    }

    public enum Units: Equatable {
        case set(UInt)
        case add(UInt)
        case subtract(UInt)
    }
}

public func parseResizeCmdArgs(_ args: [String]) -> ParsedCmd<ResizeCmdArgs> {
    parseRawCmdArgs(ResizeCmdArgs(), args)
}

private func parseDimension(arg: String, nextArgs: inout [String]) -> Parsed<ResizeCmdArgs.Dimension> {
    parseEnum(arg, ResizeCmdArgs.Dimension.self)
}

private func parseUnits(arg: String, nextArgs: inout [String]) -> Parsed<ResizeCmdArgs.Units> {
    if let number = UInt(arg.removePrefix("+").removePrefix("-")) {
        if arg.starts(with: "+") {
            return .success(.add(number))
        } else if arg.starts(with: "-") {
            return .success(.subtract(number))
        } else {
            return .success(.set(number))
        }
    } else {
        return .failure("<number> argument must be a number")
    }
}
