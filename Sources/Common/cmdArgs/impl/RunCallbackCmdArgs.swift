public struct RunCallbackCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .runCallback,
        help: run_callback_help_generated,
        flags: [
            "--for-every-window": trueBoolFlag(\.forEveryWindow),
            "--window-id": windowIdSubArgParser(),
        ],
        posArgs: [
            newMandatoryPosArgParser(\.callback, parseCallbackKind, placeholder: "<callback>"),
        ],
        conflictingOptions: [
            ["--for-every-window", "--window-id"],
        ],
    )

    /*conforms*/ public typealias ExitCodeType = Int32ExitCode
    public var forEveryWindow: Bool = false
    public var callback: Lateinit<CallbackKind> = .uninitialized

    public enum CallbackKind: String, CaseIterable, Equatable, Sendable {
        case onWindowDetected = "on-window-detected"
        case onFocusChanged = "on-focus-changed"
        case onFocusedMonitorChanged = "on-focused-monitor-changed"
    }
}

private func parseCallbackKind(i: PosArgParserInput) -> ParsedCliArgs<RunCallbackCmdArgs.CallbackKind> {
    .init(parseEnum(i.arg, RunCallbackCmdArgs.CallbackKind.self), advanceBy: 1)
}

public func parseRunCallbackCmdArgs(_ args: StrArrSlice) -> ParsedCmd<RunCallbackCmdArgs> {
    parseSpecificCmdArgs(RunCallbackCmdArgs(rawArgs: args), args)
        .filter("--for-every-window is only allowed with 'on-window-detected'") {
            $0.forEveryWindow.implies($0.callback.val == .onWindowDetected)
        }
        .filter("--window-id is only allowed with 'on-window-detected'") {
            ($0.windowId != nil).implies($0.callback.val == .onWindowDetected)
        }
}
