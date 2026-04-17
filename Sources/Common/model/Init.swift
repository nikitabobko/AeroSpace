nonisolated(unsafe) public var _isCli = true
var isCli: Bool { unsafe _isCli }
var isServer: Bool { unsafe !_isCli }

nonisolated(unsafe) public var _terminationHandler: TerminationHandler? = nil
public var terminationHandler: TerminationHandler? { unsafe _terminationHandler }

@MainActor
public protocol TerminationHandler: Sendable {
    func beforeTermination() async throws
}
