struct CloseCmdArgs: RawCmdArgs, CmdArgs {
    static let parser: CmdParser<Self> = noArgsParser(.close, allowInConfig: true)
}
struct CloseAllWindowsButCurrentCmdArgs: RawCmdArgs, CmdArgs {
    static let parser: CmdParser<Self> = noArgsParser(.closeAllWindowsButCurrent, allowInConfig: true)
}
struct FlattenWorkspaceTreeCmdArgs: RawCmdArgs, CmdArgs {
    static let parser: CmdParser<Self> = noArgsParser(.flattenWorkspaceTree, allowInConfig: true)
}
struct FullscreenCmdArgs: RawCmdArgs, CmdArgs {
    static let parser: CmdParser<Self> = noArgsParser(.fullscreen, allowInConfig: true)
}
struct ReloadConfigCmdArgs: RawCmdArgs, CmdArgs {
    static let parser: CmdParser<Self> = noArgsParser(.reloadConfig, allowInConfig: true)
}
struct WorkspaceBackAndForthCmdArgs: RawCmdArgs, CmdArgs {
    static let parser: CmdParser<Self> = noArgsParser(.workspaceBackAndForth, allowInConfig: true)
}
struct ListAppsCmdArgs: RawCmdArgs, CmdArgs {
    static let parser: CmdParser<Self> = noArgsParser(.listApps, allowInConfig: false)
}
struct VersionCmdArgs: RawCmdArgs, CmdArgs {
    static let parser: CmdParser<Self> = noArgsParser(.version, allowInConfig: false)
}

private func noArgsParser<T : Copyable>(_ kind: CmdKind, allowInConfig: Bool) -> CmdParser<T> {
    cmdParser(
        kind: kind,
        allowInConfig: allowInConfig,
        help: """
              USAGE: \(kind) [-h|--help]

              OPTIONS:
                -h, --help   Print help
              """,
        options: [:],
        arguments: []
    )
}
