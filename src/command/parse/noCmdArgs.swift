struct CloseCmdArgs: RawCmdArgs, CmdArgs {
    static let info: CmdInfo<Self> = noCmdArgsInfo(.close)
    let kind: CmdKind = .close
}
struct CloseAllWindowsButCurrentCmdArgs: RawCmdArgs, CmdArgs {
    static let info: CmdInfo<Self> = noCmdArgsInfo(.closeAllWindowsButCurrent)
    let kind: CmdKind = .closeAllWindowsButCurrent
}
struct FlattenWorkspaceTreeCmdArgs: RawCmdArgs, CmdArgs {
    static let info: CmdInfo<Self> = noCmdArgsInfo(.flattenWorkspaceTree)
    let kind: CmdKind = .flattenWorkspaceTree
}
struct FullscreenCmdArgs: RawCmdArgs, CmdArgs {
    static let info: CmdInfo<Self> = noCmdArgsInfo(.fullscreen)
    let kind: CmdKind = .fullscreen
}
struct ReloadConfigCmdArgs: RawCmdArgs, CmdArgs {
    static let info: CmdInfo<Self> = noCmdArgsInfo(.reloadConfig)
    let kind: CmdKind = .reloadConfig
}
struct WorkspaceBackAndForthCmdArgs: RawCmdArgs, CmdArgs {
    static let info: CmdInfo<Self> = noCmdArgsInfo(.workspaceBackAndForth)
    let kind: CmdKind = .workspaceBackAndForth
}

private func noCmdArgsInfo<T : Copyable>(_ kind: CmdKind) -> CmdInfo<T> {
    CmdInfo<T>(
        help: """
              USAGE: \(kind) [-h|--help]

              OPTIONS:
                -h, --help   Print help
              """,
        options: [:],
        arguments: []
    )
}
