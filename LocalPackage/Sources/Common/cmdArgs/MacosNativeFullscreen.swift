public struct MacosNativeFullscreenCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.macosNativeFullscreen, allowInConfig: true)
}
