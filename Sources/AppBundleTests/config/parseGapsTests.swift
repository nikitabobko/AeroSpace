@testable import AppBundle
import Common
import TOMLKit
import XCTest

final class ParseGapsTests: XCTestCase {
    @MainActor
    func testParseSimpleGaps() {
        let config = [
            "inner": [
                "vertical": 10,
                "horizontal": 20,
            ],
            "outer": [
                "left": 5,
                "bottom": 6,
                "top": 7,
                "right": 8,
            ],
        ].tomlValue

        var errors: [TomlParseError] = []
        let mockBacktrace: TomlBacktrace = .root
        let gaps = parseGaps(config, mockBacktrace, &errors)

        XCTAssertTrue(errors.isEmpty)

        let monitor = TestMonitor()
        let resolved = ResolvedGaps(gaps: gaps, monitor: monitor)

        XCTAssertEqual(resolved.inner.vertical, 10)
        XCTAssertEqual(resolved.inner.horizontal, 20)
        XCTAssertEqual(resolved.outer.left, 5)
        XCTAssertEqual(resolved.outer.bottom, 6)
        XCTAssertEqual(resolved.outer.top, 7)
        XCTAssertEqual(resolved.outer.right, 8)
    }

    @MainActor
    func testParsePerMonitorGaps() {
        let config = [
            "outer": [
                "top": [
                    ["monitor": ["main": ["value": 16]]],
                    8,
                ],
            ],
        ].tomlValue

        var errors: [TomlParseError] = []
        let mockBacktrace: TomlBacktrace = .root
        let gaps = parseGaps(config, mockBacktrace, &errors)

        XCTAssertTrue(errors.isEmpty)

        let mainMonitor = TestMonitor(id: "main")
        let otherMonitor = TestMonitor(id: "other")

        let mainResolved = ResolvedGaps(gaps: gaps, monitor: mainMonitor)
        let otherResolved = ResolvedGaps(gaps: gaps, monitor: otherMonitor)

        XCTAssertEqual(mainResolved.outer.top, 16)
        XCTAssertEqual(otherResolved.outer.top, 8)
    }

    @MainActor
    func testParseWindowDependentGaps() {
        let config = [
            "outer": [
                "top": [
                    ["monitor": ["main": ["value": 16, "windows": 1]]],
                    ["monitor": ["main": ["value": 32, "windows": 2]]],
                    ["monitor": ["main": ["value": 24]]],
                    8,
                ],
            ],
        ].tomlValue

        var errors: [TomlParseError] = []
        let mockBacktrace: TomlBacktrace = .root
        let gaps = parseGaps(config, mockBacktrace, &errors)

        XCTAssertTrue(errors.isEmpty)

        let mainMonitor = TestMonitor(id: "main")
        let otherMonitor = TestMonitor(id: "other")

        // Test exact window count matches
        let oneWindow = ResolvedGaps(gaps: gaps, monitor: mainMonitor, windowCount: 1)
        XCTAssertEqual(oneWindow.outer.top, 16)

        let twoWindows = ResolvedGaps(gaps: gaps, monitor: mainMonitor, windowCount: 2)
        XCTAssertEqual(twoWindows.outer.top, 32)

        // Test fallback to monitor-only value
        let threeWindows = ResolvedGaps(gaps: gaps, monitor: mainMonitor, windowCount: 3)
        XCTAssertEqual(threeWindows.outer.top, 24)

        // Test fallback to default value
        let otherMonitorGaps = ResolvedGaps(gaps: gaps, monitor: otherMonitor, windowCount: 1)
        XCTAssertEqual(otherMonitorGaps.outer.top, 8)
    }
}

@MainActor private struct TestMonitor: Monitor {
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

private extension Dictionary where Key == String {
    var tomlValue: TOMLKit.TOMLValueConvertible {
        let table = TOMLTable()
        for (key, value) in self {
            let tomlValue: TOMLValue
            if let int = value as? Int {
                tomlValue = TOMLValue(integerLiteral: int)
            } else if let dict = value as? [String: Any] {
                tomlValue = TOMLValue(dict.tomlValue as! TOMLTable)
            } else if let array = value as? [Any] {
                // Создаем TOMLArray и преобразуем его в TOMLValue
                let tomlArray = TOMLArray()
                for item in array {
                    if let dict = item as? [String: Any] {
                        let table = dict.tomlValue as! TOMLTable
                        tomlArray.append(table)
                    } else if let intValue = item as? Int {
                        tomlArray.append(intValue)
                    } else {
                        fatalError("Unsupported array item type: \(Swift.type(of: item))")
                    }
                }
                tomlValue = tomlArray.tomlValue
            } else {
                fatalError("Unsupported type")
            }
            table[key] = tomlValue
        }
        return table
    }
}
