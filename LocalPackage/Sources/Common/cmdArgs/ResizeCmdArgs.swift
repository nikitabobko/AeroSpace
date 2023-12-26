public struct ResizeCmdArgs: CmdArgs, Equatable {
    public static let info: CmdStaticInfo = RawResizeCmdArgs.info

    public let dimension: Dimension
    public let units: Units

    public init(
        dimension: Dimension,
        units: Units
    ) {
        self.dimension = dimension
        self.units = units
    }

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
    parseRawCmdArgs(RawResizeCmdArgs(), args)
        .flatMap { raw in
            .cmd(ResizeCmdArgs(
                dimension: raw.dimension,
                units: raw.units
            ))
        }
}

private struct RawResizeCmdArgs: RawCmdArgs {
    @Lateinit var dimension: ResizeCmdArgs.Dimension
    @Lateinit var units: ResizeCmdArgs.Units

    static let parser: CmdParser<Self> = cmdParser(
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
            ArgParser(\.dimension, parseDimension, argPlaceholderIfMandatory: "(smart|width|height)"),
            ArgParser(\.units, parseUnits, argPlaceholderIfMandatory: "[+|-]<number>"),
        ]
    )
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
