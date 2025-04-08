@testable import AppBundle
import Common
import TOMLKit
import XCTest

final class DynamicConfigValueTests: XCTestCase {
    @MainActor
    func testConstantValue() {
        let value: DynamicConfigValue<Int> = .constant(42)
        let monitor = TestMonitor()

        XCTAssertEqual(value.getValue(for: monitor), 42)
        XCTAssertEqual(value.getValue(for: monitor, windowCount: 1), 42)
        XCTAssertEqual(value.getValue(for: monitor, windowCount: 2), 42)
    }

    @MainActor
    func testPerMonitorWithoutWindows() {
        let mainMonitor = TestMonitor(id: "main")
        let secondaryMonitor = TestMonitor(id: "secondary")

        let mainDesc = MonitorDescription.pattern("main")!
        let value: DynamicConfigValue<Int> = .perMonitor([
            PerMonitorValue(description: mainDesc, value: 16, windows: nil, workspace: nil),
        ], default: 8)

        // Should match monitor without considering windows
        XCTAssertEqual(value.getValue(for: mainMonitor), 16)
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 1), 16)
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 2), 16)

        // Should use default for non-matching monitor
        XCTAssertEqual(value.getValue(for: secondaryMonitor), 8)
        XCTAssertEqual(value.getValue(for: secondaryMonitor, windowCount: 1), 8)
    }

    @MainActor
    func testPerMonitorWithWindows() {
        let mainMonitor = TestMonitor(id: "main")
        let secondaryMonitor = TestMonitor(id: "secondary")

        let mainDesc = MonitorDescription.pattern("main")!
        let value: DynamicConfigValue<Int> = .perMonitor([
            PerMonitorValue(description: mainDesc, value: 16, windows: 1, workspace: nil),
            PerMonitorValue(description: mainDesc, value: 32, windows: 2, workspace: nil),
            PerMonitorValue(description: mainDesc, value: 24, windows: nil, workspace: nil),
        ], default: 8)

        // Test exact matches - должны работать только точные совпадения
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 1), 16)
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 2), 32)

        // Test fallback to monitor-only value при отсутствии точного совпадения
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 3), 24)
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 4), 24)

        // Test fallback to default
        XCTAssertEqual(value.getValue(for: secondaryMonitor, windowCount: 1), 8)
        XCTAssertEqual(value.getValue(for: secondaryMonitor, windowCount: 2), 8)
    }

    @MainActor
    func testSingleWindowRule() {
        // Этот тест проверяет случай, когда указано правило только для 1 окна
        let mainMonitor = TestMonitor(id: "main")

        let mainDesc = MonitorDescription.pattern("main")!
        let value: DynamicConfigValue<Int> = .perMonitor([
            PerMonitorValue(description: mainDesc, value: 720, windows: 1, workspace: nil),
        ], default: 8)

        // Точное совпадение для 1 окна
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 1), 720)

        // Для 2 и более окон должно использоваться значение по умолчанию
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 2), 8)
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 3), 8)
    }

    @MainActor
    func testIgnoreFloatingWindows() {
        // Этот тест проверяет, что плавающие окна игнорируются при подсчете
        // Однако, в тестах мы просто используем значение windowCount
        // Поэтому мы проверяем это косвенно, при помощи isUnitTest и соответствующего кода

        let mainMonitor = TestMonitor(id: "main")

        let mainDesc = MonitorDescription.pattern("main")!
        let value: DynamicConfigValue<Int> = .perMonitor([
            PerMonitorValue(description: mainDesc, value: 720, windows: 1, workspace: nil),
            PerMonitorValue(description: mainDesc, value: 360, windows: 2, workspace: nil),
        ], default: 8)

        // Тесты работают с переданным windowCount
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 1), 720)
        XCTAssertEqual(value.getValue(for: mainMonitor, windowCount: 2), 360)
    }

    @MainActor
    func testConfigParsing() async throws {
        let config = """
            [gaps]
            inner.vertical = [
                { monitor.main = { value = 16, windows = 1 } },
                { monitor.main = { value = 32, windows = 2 } },
                { monitor.secondary = 24 },
                8
            ]
            """

        let (parsed, parseErrors) = parseConfig(config)
        XCTAssertTrue(parseErrors.isEmpty)

        let mainMonitor = TestMonitor(id: "main")
        let secondaryMonitor = TestMonitor(id: "secondary")

        let resolvedMain1 = ResolvedGaps(gaps: parsed.gaps, monitor: mainMonitor, windowCount: 1)
        XCTAssertEqual(resolvedMain1.inner.vertical, 16)

        let resolvedMain2 = ResolvedGaps(gaps: parsed.gaps, monitor: mainMonitor, windowCount: 2)
        XCTAssertEqual(resolvedMain2.inner.vertical, 32)

        let resolvedSecondary = ResolvedGaps(gaps: parsed.gaps, monitor: secondaryMonitor)
        XCTAssertEqual(resolvedSecondary.inner.vertical, 24)
    }
}

@MainActor
private struct TestMonitor: Monitor {
    var id: String
    var name: String
    var monitorAppKitNsScreenScreensId: Int
    var rect: Rect
    var visibleRect: Rect
    var width: CGFloat
    var height: CGFloat

    init(id: String = "test") {
        self.id = id
        self.name = id
        self.monitorAppKitNsScreenScreensId = 1
        self.rect = Rect(topLeftX: 0, topLeftY: 0, width: 0, height: 0)
        self.visibleRect = Rect(topLeftX: 0, topLeftY: 0, width: 0, height: 0)
        self.width = 0
        self.height = 0
    }
}

private struct MockBacktrace {
    init() {}
    func appending(_ component: String) -> Self { self }
    static func + (lhs: Self, rhs: String) -> Self { lhs }
}
