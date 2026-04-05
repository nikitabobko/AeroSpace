nonisolated(unsafe) public var _isCli = true
var isCli: Bool { unsafe _isCli }
var isServer: Bool { unsafe !_isCli }

nonisolated(unsafe) public var _terminationHandler: TerminationHandler = EmptyTerminationHandler()
public var terminationHandler: TerminationHandler { unsafe _terminationHandler }

struct EmptyTerminationHandler: TerminationHandler {
    func beforeTermination() {}
}

@MainActor
public protocol TerminationHandler: Sendable {
    func beforeTermination() async throws
}
