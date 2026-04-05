import AppKit
import Common

struct TestCommand: Command {
    let args: TestCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> TestCommandExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        let workspace = target.workspace
        if let workspacePredicate = args.workspacePredicate, workspace.name != workspacePredicate.raw {
            return ._false
        }
        if let duringAeroSpaceStartup = args.duringAeroSpaceStartup, duringAeroSpaceStartup != isStartup {
            // todo maybe worth passing startup status as env var
            return ._false
        }

        // All the predicates below require a window
        if let regex = args.windowTitleRegexSubstring {
            guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
            if !(try await window.title).contains(caseInsensitiveRegex: regex) { return ._false }
        }
        if let appBundleId = args.appBundleId {
            guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
            if window.app.rawAppBundleId != appBundleId { return ._false }
        }
        if let regex = args.appNameRegexSubstring {
            guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
            if !(window.app.name ?? "").contains(caseInsensitiveRegex: regex) { return ._false }
        }
        if let windowIdPredicate = args.windowIdPredicate {
            guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
            if windowIdPredicate != window.windowId { return ._false }
        }

        return ._true
    }
}
