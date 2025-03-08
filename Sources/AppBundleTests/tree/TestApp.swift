@testable import AppBundle
import Common

final class TestApp: AbstractApp {
    let pid: Int32
    let id: String?
    let name: String?
    let execPath: String? = nil
    let bundlePath: String? = nil
    @MainActor
    static let shared = TestApp()

    private init() {
        self.pid = 0
        self.id = "bobko.AeroSpace.test-app"
        self.name = id
    }

    var _windows: [Window] = []
    func detectNewWindows(startup: Bool) {}
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
    func getFocusedWindow(startup: Bool) -> Window? { _focusedWindow }
}
