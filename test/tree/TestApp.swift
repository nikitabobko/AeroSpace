@testable import AeroSpace_Debug

final class TestApp: AeroApp {
    static var shared = TestApp(id: 0)

    private override init(id: Int32) {
        super.init(id: id)
    }

    var _windows: [Window] = []
    override var windows: [Window]  {
        get { _windows }
        set {
            if let focusedWindow {
                check(newValue.contains(focusedWindow))
            }
            _windows = newValue
        }
    }

    private var _focusedWindow: Window? = nil
    override var focusedWindow: Window? {
        get { _focusedWindow }
        set {
            if let window = newValue {
                check(windows.contains(window))
            }
            _focusedWindow = newValue
        }
    }
}
