import Common

final class ThreadGuardedValue<Value>: Sendable {
    nonisolated(unsafe) private var _threadGuarded: Value?
    private let threadToken: AxAppThreadToken = axTaskLocalAppThreadToken ?? dieT("axTaskLocalAppThreadToken is not initialized")
    init(_ value: Value) { unsafe self._threadGuarded = value }
    var threadGuarded: Value {
        get {
            threadToken.checkEquals(axTaskLocalAppThreadToken)
            return unsafe _threadGuarded ?? dieT("Value is already destroyed")
        }
        set(newValue) {
            threadToken.checkEquals(axTaskLocalAppThreadToken)
            unsafe _threadGuarded = newValue
        }
    }
    func destroy() {
        threadToken.checkEquals(axTaskLocalAppThreadToken)
        unsafe _threadGuarded = nil
    }
    deinit {
        unsafe check(_threadGuarded == nil, "The Value must be explicitly destroyed on the appropriate thread before deinit")
    }
}
