import Common

final class ThreadGuardedValue<Value>: Sendable {
    private nonisolated(unsafe) var _threadGuarded: Value?
    private let threadToken: AxAppThreadToken = axTaskLocalAppThreadToken ?? dieT("axTaskLocalAppThreadToken is not initialized")
    init(_ value: Value) { self._threadGuarded = value }
    var threadGuarded: Value {
        get {
            threadToken.checkEquals(axTaskLocalAppThreadToken)
            return _threadGuarded ?? dieT("Value is already destroyed")
        }
        set(newValue) {
            threadToken.checkEquals(axTaskLocalAppThreadToken)
            _threadGuarded = newValue
        }
    }
    func destroy() {
        threadToken.checkEquals(axTaskLocalAppThreadToken)
        _threadGuarded = nil
    }
    deinit {
        check(_threadGuarded == nil, "The Value must be explicitly destroyed on the appropriate thread before deinit")
    }
}
