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
                precondition(newValue.contains(focusedWindow))
            }
            _windows = newValue
        }
    }

    private var _focusedWindow: Window? = nil
    override var focusedWindow: Window? {
        get { _focusedWindow }
        set {
            if let window = newValue {
                precondition(windows.contains(window))
            }
            _focusedWindow = newValue
        }
    }
}
