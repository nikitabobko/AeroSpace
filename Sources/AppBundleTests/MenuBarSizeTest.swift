@testable import AppBundle
import XCTest

final class MenuBarSizeTest: XCTestCase {
    private let defaults = UserDefaults.standard
    private let key = ExperimentalUISettingsItems.size.rawValue
    private var previousValue: Any?

    override func setUp() {
        previousValue = defaults.object(forKey: key)
        defaults.removeObject(forKey: key)
    }

    override func tearDown() {
        if let previousValue {
            defaults.set(previousValue, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func testPointSizes() {
        assertEquals(MenuBarSize.small.pointSize, 24)
        assertEquals(MenuBarSize.medium.pointSize, 32)
        assertEquals(MenuBarSize.large.pointSize, 40)
    }

    func testDefaultsToLarge() {
        assertEquals(ExperimentalUISettings().size, .large)
        defaults.set("invalid", forKey: key)
        assertEquals(ExperimentalUISettings().size, .large)
    }

    func testSelectionPersists() {
        var settings = ExperimentalUISettings()
        for size in MenuBarSize.allCases {
            settings.size = size
            assertEquals(ExperimentalUISettings().size, size)
        }
    }
}
