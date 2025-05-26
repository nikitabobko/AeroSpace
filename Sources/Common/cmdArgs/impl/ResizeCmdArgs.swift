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
        case setPercent(UInt)
        case addPercent(UInt)
        case subtractPercent(UInt)
    }
}

public func parseResizeCmdArgs(_ args: [String]) -> ParsedCmd<ResizeCmdArgs> {
    parseSpecificCmdArgs(ResizeCmdArgs(rawArgs: args), args)
}

private func parseDimension(arg: String, nextArgs: inout [String]) -> Parsed<ResizeCmdArgs.Dimension> {
    parseEnum(arg, ResizeCmdArgs.Dimension.self)
}

private func parseUnits(arg: String, nextArgs: inout [String]) -> Parsed<ResizeCmdArgs.Units> {
    // Check if it's a percentage
    if arg.hasSuffix("%") {
        let valueStr = arg.dropLast()

        // Check for empty percentage
        if valueStr.isEmpty {
            return .failure("Invalid percentage format")
        }

        // Check if it contains a decimal point
        if valueStr.contains(".") {
            return .failure("Percentage must be a whole number")
        }

        // Try to parse the percentage value
        let withoutPrefix = valueStr.hasPrefix("+") || valueStr.hasPrefix("-")
            ? String(valueStr.dropFirst())
            : String(valueStr)

        guard let number = UInt(withoutPrefix) else {
            return .failure("Invalid percentage format")
        }

        // Check bounds for absolute percentages
        if !valueStr.hasPrefix("+") && !valueStr.hasPrefix("-") && number > 100 {
            return .failure("Percentage must be between 0 and 100")
        }

        // Check bounds for relative percentages (can't result in negative or > 100)
        if valueStr.hasPrefix("-") && number > 100 {
            return .failure("Percentage must be between 0 and 100")
        }

        return switch () {
            case _ where valueStr.hasPrefix("+"): .success(.addPercent(number))
            case _ where valueStr.hasPrefix("-"): .success(.subtractPercent(number))
            default: .success(.setPercent(number))
        }
    } else {
        // Original pixel parsing logic
        if let number = UInt(arg.removePrefix("+").removePrefix("-")) {
            return switch () {
                case _ where arg.starts(with: "+"): .success(.add(number))
                case _ where arg.starts(with: "-"): .success(.subtract(number))
                default: .success(.set(number))
            }
        } else {
            return .failure("<number> argument must be a number")
        }
    }
}
