public struct SetFrameCmdArgs: CmdArgs {
    public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .setFrame,
        allowInConfig: true,
        help: set_frame_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
            "--x": ArgParser(\.rawX, parseSingleFrameValue),
            "--y": ArgParser(\.rawY, parseSingleFrameValue),
            "--width": ArgParser(\.rawWidth, parseSingleFrameValue),
            "--height": ArgParser(\.rawHeight, parseSingleFrameValue),
        ],
        posArgs: [],
    )

    public var rawX: FrameValue?
    public var rawY: FrameValue?
    public var rawWidth: FrameValue?
    public var rawHeight: FrameValue?
}

public enum FrameValue: Equatable, Sendable {
    case set(Int)
    case add(Int)
    case subtract(Int)
}

func parseSetFrameCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SetFrameCmdArgs> {
    parseSpecificCmdArgs(SetFrameCmdArgs(rawArgs: args), args)
        .filter("At least one of --x, --y, --width, --height must be specified") { raw in
            raw.rawX != nil || raw.rawY != nil || raw.rawWidth != nil || raw.rawHeight != nil
        }
}

private func parseSingleFrameValue(input: SubArgParserInput) -> ParsedCliArgs<FrameValue?> {
    // Use argOrNil instead of nonFlagArgOrNil because values can start with "-" (negative/subtract)
    if let arg = input.argOrNil {
        let stripped = arg.removePrefix("+").removePrefix("-")
        if let number = Int(stripped) {
            switch true {
                case arg.starts(with: "+"): return .succ(.add(number), advanceBy: 1)
                case arg.starts(with: "-"): return .succ(.subtract(number), advanceBy: 1)
                default: return .succ(.set(number), advanceBy: 1)
            }
        } else {
            return .fail("'\(arg)' is not a valid integer", advanceBy: 1)
        }
    } else {
        return .fail("Expected a value after flag", advanceBy: 0)
    }
}
