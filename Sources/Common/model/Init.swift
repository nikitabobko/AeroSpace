nonisolated(unsafe) public var isCli = true
public var isServer: Bool { !isCli }

nonisolated(unsafe) public var terminationHandler: TerminationHandler = EmptyTerminationHandler()

struct EmptyTerminationHandler: TerminationHandler {
    func beforeTermination() {}
}

@MainActor
public protocol TerminationHandler: Sendable {
    func beforeTermination() async throws
}
