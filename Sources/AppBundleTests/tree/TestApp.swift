@testable import AppBundle
import Common

final class TestApp: AbstractApp {
    @MainActor
    static let shared = TestApp()

    private init() {
        super.init(pid: 0, id: "bobko.AeroSpace.test-app")
    }

    var _windows: [Window] = []
    override func detectNewWindows(startup: Bool) {}
    var windows: [Window] {
        get { _windows }
        set {
            if let focusedWindow {
                check(newValue.contains(focusedWindow))
            }
            _windows = newValue
        }
    }

    private var _focusedWindow: Window? = nil
    var focusedWindow: Window? {
        get { _focusedWindow }
        set {
            if let window = newValue {
                check(windows.contains(window))
            }
            _focusedWindow = newValue
        }
    }
    override func getFocusedWindow(startup: Bool) -> Window? { _focusedWindow }
}
