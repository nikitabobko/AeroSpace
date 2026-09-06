import AppKit
import Common
import Foundation

private let axMessagingTimeoutSeconds: Float = 0.25

@MainActor public func initAppBundle() {
    Task.startUnstructured {
        initTerminationHandler()
        unsafe _isCli = false
        initServerArgs()
        await waitForAccessibilityPermission_nonCancellable()
        configureAxMessagingTimeout()
        if isDebug {
            await toggleReleaseServerIfDebug(.off)
            interceptTermination(SIGINT)
            interceptTermination(SIGKILL)
        }

        await bootstrapConfig_nonCancellable()
        _ = await reloadConfig_nonCancellable()

        startUnixSocketServer()
        GlobalObserver.initObserver()
        Workspace.garbageCollectUnusedWorkspaces() // init workspaces
        _ = Workspace.all.first?.focusWorkspace()
        await runHeavyCompleteRefreshSession(
            .startup,
            // It's important for the first initialization to be non cancellable
            // to make sure that isStartup propagates to all places
            assumeCancellable: false,
            layoutWorkspaces: false,
        )
        try await runLightSession(.startup, .forceRun) {
            smartLayoutAtStartup()
            _ = await config.afterStartupCommand.run(.defaultEnv, .emptyStdin)
        }
    }
}

private func configureAxMessagingTimeout() {
    // The system default is long enough for one unresponsive application to
    // stall a refresh and every command waiting behind it. Per-app AX threads
    // isolate the blocking call; this timeout bounds how long callers wait for
    // that thread before the failed request is retried by a future refresh.
    let result = AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), axMessagingTimeoutSeconds)
    check(result == .success, "Can't configure the Accessibility API messaging timeout: \(result.rawValue)")
}

@MainActor private func bootstrapConfig_nonCancellable() async {
    let result = await reloadConfig_nonCancellable(forceConfigUrl: defaultConfigUrl)
    let msg = """
        Can't load default config. Your installation is probably corrupted.
        Please don't modify \(defaultConfigUrl.description.singleQuoted)

        \(result.stdout)
        """
    check(result.isOk, msg)
}

@MainActor
private func smartLayoutAtStartup() {
    let workspace = focus.workspace
    let root = workspace.rootTilingContainer
    switch root.children.count <= 3 {
        case true: root.layout = .tiles
        case false: root.layout = .accordion
    }
}

var isStartup: Bool { refreshSessionEvent?.isStartup == true }

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
