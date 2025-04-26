public struct VolumeCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .volume,
        allowInConfig: true,
        help: volume_help_generated,
        options: [:],
        arguments: [newArgParser(\.action, parseVolumeAction, mandatoryArgPlaceholder: VolumeAction.argsUnion)]
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?

    public var action: Lateinit<VolumeAction> = .uninitialized
}

public enum VolumeAction: Equatable, Sendable {
    case up, down, muteToggle, muteOn, muteOff
    case set(Int)

    static let argsUnion: String = "(up|down|mute-toggle|mute-on|mute-off|set)"
}

func parseVolumeAction(arg: String, nextArgs: inout [String]) -> Parsed<VolumeAction> {
    switch arg {
        case "up": return .success(.up)
        case "down": return .success(.down)
        case "mute-toggle": return .success(.muteToggle)
        case "mute-off": return .success(.muteOff)
        case "mute-on": return .success(.muteOn)
        case "set":
            guard let arg = nextArgs.nextNonFlagOrNil() else { return .failure("set argument must be followed by <number>") }
            guard let int = Int(arg) else { return .failure("Can't parse number '\(arg)'") }
            if !(0 ... 100).contains(int) { return .failure("\(int) must be in range from 0 to 100") }
            return .success(.set(int))
        default:
            return .failure("Unknown argument '\(arg)'. Possible values: \(VolumeAction.argsUnion)")
    }
}
