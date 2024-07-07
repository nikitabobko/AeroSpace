public var isCli = true
public var isServer: Bool { !isCli }

public var terminationHandler: TerminationHandler = EmptyTerminationHandler()

struct EmptyTerminationHandler: TerminationHandler {
    func beforeTermination() {}
}

public protocol TerminationHandler {
    func beforeTermination()
}
