import Common

struct ResizeCmdArgs: CmdArgs, Equatable {
    static let info: CmdStaticInfo = RawResizeCmdArgs.info

    let dimension: Dimension
    let units: Units

    enum Dimension: String, CaseIterable, Equatable {
        case width, height, smart
    }

    enum Units: Equatable {
        case set(UInt)
        case add(UInt)
        case subtract(UInt)
    }
}

func parseResizeCmdArgs(_ args: [String]) -> ParsedCmd<ResizeCmdArgs> {
    parseRawCmdArgs(RawResizeCmdArgs(), args)
        .flatMap { raw in
            guard let dimension = raw.dimension else { return .failure("\(ResizeCmdArgs.Dimension.unionLiteral) argument is mandatory") }
            guard let units = raw.units else { return .failure("<number> argument is mandatory") }
            return .cmd(ResizeCmdArgs(
                dimension: dimension,
                units: units
            ))
        }
}

private struct RawResizeCmdArgs: RawCmdArgs {
    var dimension: ResizeCmdArgs.Dimension?
    var units: ResizeCmdArgs.Units?

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
            ArgParser(\.dimension, parseDimension),
            ArgParser(\.units, parseUnits),
        ]
    )
}

private func parseDimension(_ raw: String) -> Parsed<ResizeCmdArgs.Dimension> {
    parseEnum(raw, ResizeCmdArgs.Dimension.self)
}

private func parseUnits(_ raw: String) -> Parsed<ResizeCmdArgs.Units> {
    if let number = UInt(raw.removePrefix("+").removePrefix("-")) {
        if raw.starts(with: "+") {
            return .success(.add(number))
        } else if raw.starts(with: "-") {
            return .success(.subtract(number))
        } else {
            return .success(.set(number))
        }
    } else {
        return .failure("<number> argument must be a number")
    }
}
