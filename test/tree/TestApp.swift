@testable import AeroSpace_Debug

final class TestApp: AeroApp {
    static var shared = TestApp(id: 0)

    private override init(id: Int32) {
        super.init(id: id)
    }

    var _windows: [TestWindow] = []
    var windows: [TestWindow]  {
        get { _windows }
        set {
            if let focusedWindow {
                precondition(newValue.contains(focusedWindow))
            }
            _windows = newValue
        }
    }

    private var _focusedWindow: TestWindow? = nil
    override var focusedWindow: TestWindow? {
        get { _focusedWindow }
        set {
            if let window = newValue {
                precondition(windows.contains(window))
            }
            _focusedWindow = newValue
        }
    }
}
