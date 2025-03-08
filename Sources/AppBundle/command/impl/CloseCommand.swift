import AppKit
import Common

struct CloseCommand: Command {
    let args: CloseCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        try await allowOnlyCancellationError {
            guard let target = args.resolveTargetOrReportError(env, io) else { return false }
            guard let window = target.windowOrNil else {
                return io.err("Empty workspace")
            }
            // Access ax directly. Not cool :(
            if try await args.quitIfLastWindow.andAsync(MainActor.shared, { try await window.macAppUnsafe.getWindowsCount() == 1 }) {
                if window.macAppUnsafe.nsApp.terminate() {
                    window.asMacWindow().garbageCollect(skipClosedWindowsCache: true)
                    return true
                } else {
                    return io.err("Failed to quit '\(window.app.name ?? "Unknown app")'")
                }
            } else {
                window.close()
                return true
            }
        }
    }
}

public extension Bool {
    // Workaround for https://forums.swift.org/t/using-async-call-in-boolean-expression/52943
    // https://github.com/swiftlang/swift/issues/56869
    @inlinable
    func andAsync(isolation: isolated (any Actor)? = #isolation, _ rhs: () async throws -> Bool) async rethrows -> Bool {
        if self {
            return try await rhs()
        }
        return false
    }

    // https://forums.swift.org/t/potential-false-positive-sending-risks-causing-data-races/78859
    // https://github.com/swiftlang/swift/issues/56869
    @inlinable
    func andAsync(_ actor: isolated MainActor, _ rhs: @MainActor () async throws -> Bool) async rethrows -> Bool {
        if self {
            return try await rhs()
        }
        return false
    }
}
