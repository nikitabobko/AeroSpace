public nonisolated(unsafe) var isCli = true
public var isServer: Bool { !isCli }

public nonisolated(unsafe) var terminationHandler: TerminationHandler = EmptyTerminationHandler()

struct EmptyTerminationHandler: TerminationHandler {
    func beforeTermination() {}
}

@MainActor
public protocol TerminationHandler: Sendable {
    func beforeTermination()
}
