public var isCli = true
public var isServer: Bool { !isCli }

public var _terminationHandler: TerminationHandler? = nil
public var terminationHandler: TerminationHandler { _terminationHandler! }

public protocol TerminationHandler {
    func beforeTermination()
}
