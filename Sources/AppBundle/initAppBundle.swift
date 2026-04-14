import AppKit
import Common
import Foundation

@MainActor public func initAppBundle() {
    Task {
        initTerminationHandler()
        unsafe _isCli = false
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
                Please don't modify \(defaultConfigUrl.description.singleQuoted)

                \(out)
                """,
            )
        }

        checkAccessibilityPermissions()
        startUnixSocketServer()
        GlobalObserver.initObserver()
        Workspace.garbageCollectUnusedWorkspaces() // init workspaces
        _ = Workspace.all.first?.focusWorkspace()
        await runHeavyCompleteRefreshSession(
            .startup,
            // It's important for the first initialization to be non cancellable
            // to make sure that isStartup propagates // to all places
            cancellable: false,
            layoutWorkspaces: false,
        )
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
    if config.defaultRootContainerLayout == .scrolling {
        root.layout = .scrolling
        root.changeOrientation(.h)
        root.reveal(focus.windowOrNil, preferRightPane: true)
        return
    }
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
var serverArgs: ServerArgs { unsafe _serverArgs }
private func initServerArgs() {
    let args = CommandLine.arguments.slice(1...) ?? []
    if args.contains(where: { $0 == "-h" || $0 == "--help" }) {
        exit(EXIT_CODE_ZERO, out: serverHelp)
    }
    var index = 0
    while index < args.count {
        let current = args[index]
        index += 1
        switch current {
            case "--version", "-v":
                exit(EXIT_CODE_ZERO, out: "\(aeroSpaceAppVersion) \(gitHash)")
            case "--config-path":
                switch args.getOrNil(atIndex: index) {
                    case let arg?: unsafe _serverArgs.configLocation = arg
                    case nil: exit(EXIT_CODE_TWO, err: "Missing <path> in --config-path flag")
                }
                index += 1
            case "--read-only": // todo rename to '--disabled' and unite with disabled feature
                unsafe _serverArgs.isReadOnly = true
            case "-NSDocumentRevisionsDebugMode" where isDebug:
                // Skip Xcode CLI args.
                // Usually it's '-NSDocumentRevisionsDebugMode NO'/'-NSDocumentRevisionsDebugMode YES'
                while args.getOrNil(atIndex: index)?.starts(with: "-") == false { index += 1 }
            default:
                exit(EXIT_CODE_TWO, err: "Unrecognized flag \(args.first.orDie().singleQuoted)")
        }
    }
    if let path = serverArgs.configLocation, !FileManager.default.fileExists(atPath: path) {
        exit(EXIT_CODE_TWO, err: "\(path) doesn't exist")
    }
}
