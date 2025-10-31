public struct VolumeCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .volume,
        allowInConfig: true,
        help: volume_help_generated,
        flags: [:],
        posArgs: [newArgParser(\.action, parseVolumeAction, mandatoryArgPlaceholder: VolumeAction.argsUnion)],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public var action: Lateinit<VolumeAction> = .uninitialized
}

public enum VolumeAction: Equatable, Sendable {
    case up, down, muteToggle, muteOn, muteOff
    case set(Int)

    static let argsUnion: String = "(up|down|mute-toggle|mute-on|mute-off|set)"
}

func parseVolumeAction(i: ArgParserInput) -> ParsedCliArgs<VolumeAction> {
    switch i.arg {
        case "up": return .succ(.up, advanceBy: 1)
        case "down": return .succ(.down, advanceBy: 1)
        case "mute-toggle": return .succ(.muteToggle, advanceBy: 1)
        case "mute-off": return .succ(.muteOff, advanceBy: 1)
        case "mute-on": return .succ(.muteOn, advanceBy: 1)
        case "set":
            guard let arg = i.getOrNil(relativeIndex: 1) else { return .fail("set argument must be followed by <number>", advanceBy: 1) }
            guard let int = Int(arg) else { return .fail("Can't parse number '\(arg)'", advanceBy: 2) }
            if !(0 ... 100).contains(int) { return .fail("\(int) must be in range from 0 to 100", advanceBy: 2) }
            return .succ(.set(int), advanceBy: 2)
        default:
            return .fail("Unknown argument '\(i.arg)'. Possible values: \(VolumeAction.argsUnion)", advanceBy: 1)
    }
}
