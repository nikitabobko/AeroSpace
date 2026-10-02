public struct CycleSizeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .cycleSize,
        help: cycle_size_help_generated,
        flags: [
            "--axis": ArgParser(\.rawAxis, upcastArgParserFun(parseAxis)),
        ],
        posArgs: [newMandatoryPosArgParser(\.sizes, parseSizes, placeholder: "(<size>%)...")],
    )

    public var rawAxis: ResizeCmdArgs.Dimension? = nil
    /// Percentages of the parent container. Each one is in range 1-99
    public var sizes: Lateinit<[UInt]> = .uninitialized

    public init(rawArgs: [String], sizes: [UInt], axis: ResizeCmdArgs.Dimension? = nil) {
        self.commonState = .init(rawArgs.slice)
        self.sizes = .initialized(sizes)
        self.rawAxis = axis
    }
}

extension CycleSizeCmdArgs {
    public var axis: ResizeCmdArgs.Dimension { rawAxis ?? .smart }
}

func parseCycleSizeCmdArgs(_ args: StrArrSlice) -> ParsedCmd<CycleSizeCmdArgs> {
    parseSpecificCmdArgs(CycleSizeCmdArgs(rawArgs: args), args)
        .map {
            check(!$0.sizes.val.isEmpty)
            return $0
        }
}

private func parseAxis(i: SubArgParserInput) -> ParsedCliArgs<ResizeCmdArgs.Dimension> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(parseEnum(arg, ResizeCmdArgs.Dimension.self), advanceBy: 1)
    } else {
        return .fail("<axis> is mandatory", advanceBy: 0)
    }
}

private func parseSizes(input: PosArgParserInput) -> ParsedCliArgs<[UInt]> {
    let args = input.nonFlagArgs()

    var result: [UInt] = []
    var i = 0
    for arg in args {
        if let size = arg.parseSizePercentage() {
            result.append(size)
        } else {
            return .fail(
                "Can't parse '\(arg)'\n<size> must be an integer in range 1-99 followed by '%'. For example: 50%",
                advanceBy: i + 1,
            )
        }
        i += 1
    }

    return .succ(result, advanceBy: args.count)
}

extension String {
    fileprivate func parseSizePercentage() -> UInt? {
        guard hasSuffix("%"), let size = UInt(dropLast()), (1 ... 99).contains(size) else { return nil }
        return size
    }
}
