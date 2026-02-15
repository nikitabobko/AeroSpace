public struct AdjustAccordionPaddingCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .adjustAccordionPadding,
        allowInConfig: true,
        help: adjust_accordion_padding_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [
            newArgParser(\.units, parseAdjustAccordionPaddingUnits, mandatoryArgPlaceholder: "[+|-]<number>"),
        ],
    )

    public var units: Lateinit<AdjustAccordionPaddingCmdArgs.Units> = .uninitialized

    public init(rawArgs: [String], units: Units) {
        self.commonState = .init(rawArgs.slice)
        self.units = .initialized(units)
    }

    public enum Units: Equatable, Sendable {
        case add(UInt)
        case subtract(UInt)
    }
}

public func parseAdjustAccordionPaddingCmdArgs(_ args: StrArrSlice) -> ParsedCmd<AdjustAccordionPaddingCmdArgs> {
    parseSpecificCmdArgs(AdjustAccordionPaddingCmdArgs(rawArgs: args), args)
}

private func parseAdjustAccordionPaddingUnits(i: ArgParserInput) -> ParsedCliArgs<AdjustAccordionPaddingCmdArgs.Units> {
    if let number = UInt(i.arg.removePrefix("+").removePrefix("-")) {
        switch true {
            case i.arg.starts(with: "+"): .succ(.add(number), advanceBy: 1)
            case i.arg.starts(with: "-"): .succ(.subtract(number), advanceBy: 1)
            default: .fail("Argument must start with '+' or '-'", advanceBy: 1)
        }
    } else {
        .fail("<number> argument must be a number", advanceBy: 1)
    }
}
