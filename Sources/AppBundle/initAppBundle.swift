import AppKit
import Common
import Foundation

@MainActor public func initAppBundle() {
    Task {
        initTerminationHandler()
        isCli = false
        initServerArgs()
        if isDebug {
            await toggleReleaseServerIfDebug(.off)
            interceptTermination(SIGINT)
            interceptTermination(SIGKILL)
        }
        if try await !reloadConfig() {
            var out = ""
            check(
                try await reloadConfig(forceConfigUrl: defaultConfigUrl, stdout: &out),
                """
                Can't load default config. Your installation is probably corrupted.
                Please don't modify '\(defaultConfigUrl)'

                \(out)
                """,
            )
        }

        checkAccessibilityPermissions()
        startUnixSocketServer()
        GlobalObserver.initObserver()
        Workspace.garbageCollectUnusedWorkspaces() // init workspaces
        _ = Workspace.all.first?.focusWorkspace()
        try await runRefreshSessionBlocking(.startup, layoutWorkspaces: false)
        try await runLightSession(.startup, .forceRun) {
            smartLayoutAtStartup()
            _ = try await config.afterStartupCommand.runCmdSeq(.defaultEnv, .emptyStdin)
        }
    }
}

@MainActor
private func smartLayoutAtStartup() {
    let workspace = focus.workspace
    let root = workspace.rootTilingContainer
    if root.children.count <= 3 {
        root.layout = .tiles
    } else {
        root.layout = .accordion
    }
}

@TaskLocal
var _isStartup: Bool? = false
var isStartup: Bool { _isStartup ?? dieT("isStartup is not initialized") }

struct ServerArgs: Sendable {
    var configLocation: String? = nil
    var isReadOnly: Bool = false
}

private let serverHelp = """
    USAGE: \(CommandLine.arguments.first ?? "AeroSpace.app/Contents/MacOS/AeroSpace") [<options>]

    OPTIONS:
      -h, --help              Print help
      -v, --version           Print AeroSpace.app version
      --config-path <path>    Config path. It will take priority over ~/.aerospace.toml
                              and ${XDG_CONFIG_HOME}/aerospace/aerospace.toml
      --read-only             Disable window management.
                              Useful if you want to use only debug-windows or other query commands.
    """

nonisolated(unsafe) private var _serverArgs = ServerArgs()
var serverArgs: ServerArgs { _serverArgs }
private func initServerArgs() {
    let args = CommandLine.arguments.slice(1...) ?? []
    if args.contains(where: { $0 == "-h" || $0 == "--help" }) {
        print(serverHelp)
        exit(0)
    }
    var index = 0
    while index < args.count {
        let current = args[index]
        index += 1
        switch current {
            case "--version", "-v":
                print("\(aeroSpaceAppVersion) \(gitHash)")
                exit(0)
            case "--config-path":
                if let arg = args.getOrNil(atIndex: index) {
                    _serverArgs.configLocation = arg
                } else {
                    exit(stderrMsg: "Missing <path> in --config-path flag")
                }
                index += 1
            case "--read-only": // todo rename to '--disabled' and unite with disabled feature
                _serverArgs.isReadOnly = true
            case "-NSDocumentRevisionsDebugMode" where isDebug:
                // Skip Xcode CLI args.
                // Usually it's '-NSDocumentRevisionsDebugMode NO'/'-NSDocumentRevisionsDebugMode YES'
                while args.getOrNil(atIndex: index)?.starts(with: "-") == false { index += 1 }
            default:
                exit(stderrMsg: "Unrecognized flag '\(args.first.orDie())'")
        }
    }
    if let path = serverArgs.configLocation, !FileManager.default.fileExists(atPath: path) {
        exit(stderrMsg: "\(path) doesn't exist")
    }
}
