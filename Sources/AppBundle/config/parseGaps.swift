import Common
import TOMLKit

struct Gaps: ConvenienceCopyable, Equatable, Sendable {
    var inner: Inner
    var outer: Outer

    static let zero = Gaps(inner: .zero, outer: .zero)

    struct Inner: ConvenienceCopyable, Equatable, Sendable {
        var vertical: DynamicConfigValue<DimensionValue>
        var horizontal: DynamicConfigValue<DimensionValue>

        static let zero = Inner(vertical: .pixels(0), horizontal: .pixels(0))

        init(vertical: DimensionValue, horizontal: DimensionValue) {
            self.vertical = .constant(vertical)
            self.horizontal = .constant(horizontal)
        }

        init(vertical: DynamicConfigValue<DimensionValue>, horizontal: DynamicConfigValue<DimensionValue>) {
            self.vertical = vertical
            self.horizontal = horizontal
        }
    }

    struct Outer: ConvenienceCopyable, Equatable, Sendable {
        var left: DynamicConfigValue<DimensionValue>
        var bottom: DynamicConfigValue<DimensionValue>
        var top: DynamicConfigValue<DimensionValue>
        var right: DynamicConfigValue<DimensionValue>

        static let zero = Outer(left: .pixels(0), bottom: .pixels(0), top: .pixels(0), right: .pixels(0))

        init(left: DimensionValue, bottom: DimensionValue, top: DimensionValue, right: DimensionValue) {
            self.left = .constant(left)
            self.bottom = .constant(bottom)
            self.top = .constant(top)
            self.right = .constant(right)
        }

        init(left: DynamicConfigValue<DimensionValue>, bottom: DynamicConfigValue<DimensionValue>, top: DynamicConfigValue<DimensionValue>, right: DynamicConfigValue<DimensionValue>) {
            self.left = left
            self.bottom = bottom
            self.top = top
            self.right = right
        }
    }
}

struct ResolvedGaps {
    let inner: Inner
    let outer: Outer

    struct Inner {
        let vertical: Int
        let horizontal: Int

        func get(_ orientation: Orientation) -> Int {
            orientation == .h ? horizontal : vertical
        }
    }

    struct Outer {
        let left: Int
        let bottom: Int
        let top: Int
        let right: Int
    }

    init(gaps: Gaps, monitor: any Monitor) {
        inner = .init(
            vertical: gaps.inner.vertical.getValue(for: monitor).toPixels(totalDimension: monitor.visibleRect.height),
            horizontal: gaps.inner.horizontal.getValue(for: monitor).toPixels(totalDimension: monitor.visibleRect.width),
        )

        outer = .init(
            left: gaps.outer.left.getValue(for: monitor).toPixels(totalDimension: monitor.visibleRect.width),
            bottom: gaps.outer.bottom.getValue(for: monitor).toPixels(totalDimension: monitor.visibleRect.height),
            top: gaps.outer.top.getValue(for: monitor).toPixels(totalDimension: monitor.visibleRect.height),
            right: gaps.outer.right.getValue(for: monitor).toPixels(totalDimension: monitor.visibleRect.width),
        )
    }
}

private let gapsParser: [String: any ParserProtocol<Gaps>] = [
    "inner": Parser(\.inner, parseInner),
    "outer": Parser(\.outer, parseOuter),
]

private let innerParser: [String: any ParserProtocol<Gaps.Inner>] = [
    "vertical": Parser(\.vertical) { value, backtrace, errors in parseDynamicDimensionValue(value, backtrace, &errors) },
    "horizontal": Parser(\.horizontal) { value, backtrace, errors in parseDynamicDimensionValue(value, backtrace, &errors) },
]

private let outerParser: [String: any ParserProtocol<Gaps.Outer>] = [
    "left": Parser(\.left) { value, backtrace, errors in parseDynamicDimensionValue(value, backtrace, &errors) },
    "bottom": Parser(\.bottom) { value, backtrace, errors in parseDynamicDimensionValue(value, backtrace, &errors) },
    "top": Parser(\.top) { value, backtrace, errors in parseDynamicDimensionValue(value, backtrace, &errors) },
    "right": Parser(\.right) { value, backtrace, errors in parseDynamicDimensionValue(value, backtrace, &errors) },
]

func parseGaps(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Gaps {
    parseTable(raw, .zero, gapsParser, backtrace, &errors)
}

func parseInner(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Gaps.Inner {
    parseTable(raw, Gaps.Inner.zero, innerParser, backtrace, &errors)
}

func parseOuter(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Gaps.Outer {
    parseTable(raw, Gaps.Outer.zero, outerParser, backtrace, &errors)
}

func parseDynamicDimensionValue(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError]
) -> DynamicConfigValue<DimensionValue> {
    // Handle simple value (either int or string with %)
    if let intValue = raw.int {
        return .constant(.pixels(intValue))
    } else if let strValue = raw.string {
        if let dimensionValue = DimensionValue.parse(strValue) {
            return .constant(dimensionValue)
        } else {
            errors.append(.semantic(backtrace, "Invalid dimension value: '\(strValue)'. Expected integer or percentage (e.g., '10' or '10%')"))
            return .constant(.pixels(0))
        }
    } else if let array = raw.array {
        // Handle array for per-monitor values
        if array.isEmpty {
            errors.append(.semantic(backtrace, "The array must not be empty"))
            return .constant(.pixels(0))
        }

        // Parse default value from last element
        let defaultValue: DimensionValue
        if let lastInt = array.last?.int {
            defaultValue = .pixels(lastInt)
        } else if let lastStr = array.last?.string, let parsed = DimensionValue.parse(lastStr) {
            defaultValue = parsed
        } else {
            errors.append(.semantic(backtrace, "The last item in the array must be a valid dimension value"))
            return .constant(.pixels(0))
        }

        if array.dropLast().isEmpty {
            errors.append(.semantic(backtrace, "The array must contain at least one monitor pattern"))
            return .constant(defaultValue)
        }

        let rules: [PerMonitorValue<DimensionValue>] = parsePerMonitorDimensionValues(TOMLArray(array.dropLast()), backtrace, &errors)

        return .perMonitor(rules, default: defaultValue)
    } else {
        errors.append(.semantic(backtrace, "Unsupported type: \(raw.type), expected: integer, string, or array"))
        return .constant(.pixels(0))
    }
}

func parsePerMonitorDimensionValues(_ array: TOMLArray, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [PerMonitorValue<DimensionValue>] {
    array.enumerated().compactMap { (index: Int, raw: TOMLValueConvertible) -> PerMonitorValue<DimensionValue>? in
        var backtrace = backtrace + .index(index)

        guard let (key, value) = raw.unwrapTableWithSingleKey(expectedKey: "monitor", &backtrace)
            .flatMap({ $0.value.unwrapTableWithSingleKey(expectedKey: nil, &backtrace) })
            .getOrNil(appendErrorTo: &errors)
        else {
            return nil
        }

        let monitorDescriptionResult = parseMonitorDescription(key, backtrace)

        guard let monitorDescription = monitorDescriptionResult.getOrNil(appendErrorTo: &errors) else { return nil }

        let dimensionValue: DimensionValue
        if let intValue = value.int {
            dimensionValue = .pixels(intValue)
        } else if let strValue = value.string, let parsed = DimensionValue.parse(strValue) {
            dimensionValue = parsed
        } else {
            errors.append(.semantic(backtrace, "Expected dimension value (integer or percentage string). But actual type is '\(value.type)'"))
            return nil
        }

        return PerMonitorValue(description: monitorDescription, value: dimensionValue)
    }
}
