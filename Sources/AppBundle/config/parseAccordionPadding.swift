import AppKit
import Common
import TOMLKit

// MARK: - AccordionPaddingUnit

enum AccordionPaddingUnit: Equatable, Sendable {
    case absolute(Int)
    case percent(Double)

    func resolve(containerDimension: CGFloat) -> CGFloat {
        switch self {
            case .absolute(let px): CGFloat(px)
            case .percent(let pct): containerDimension * CGFloat(pct / 100.0)
        }
    }
}

// MARK: - AccordionPadding

struct AccordionPadding: ConvenienceCopyable, Equatable, Sendable {
    var horizontal: DynamicConfigValue<AccordionPaddingUnit>
    var vertical: DynamicConfigValue<AccordionPaddingUnit>

    static let `default` = AccordionPadding(
        horizontal: .constant(.absolute(30)),
        vertical: .constant(.absolute(30)),
    )
}

// MARK: - ResolvedAccordionPadding

struct ResolvedAccordionPadding {
    let horizontal: AccordionPaddingUnit
    let vertical: AccordionPaddingUnit

    func resolve(_ orientation: Orientation, containerDimension: CGFloat) -> CGFloat {
        switch orientation {
            case .h: horizontal.resolve(containerDimension: containerDimension)
            case .v: vertical.resolve(containerDimension: containerDimension)
        }
    }

    init(padding: AccordionPadding, monitor: any Monitor) {
        horizontal = padding.horizontal.getValue(for: monitor)
        vertical = padding.vertical.getValue(for: monitor)
    }
}

// MARK: - Parsers

private let accordionPaddingAxisParser: [String: any ParserProtocol<AccordionPadding>] = [
    "horizontal": Parser(\.horizontal) { value, backtrace, errors in
        parseDynamicValue(value, AccordionPaddingUnit.self, .absolute(30), backtrace, &errors, parseAccordionPaddingUnit)
    },
    "vertical": Parser(\.vertical) { value, backtrace, errors in
        parseDynamicValue(value, AccordionPaddingUnit.self, .absolute(30), backtrace, &errors, parseAccordionPaddingUnit)
    },
]

func parseAccordionPadding(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> AccordionPadding {
    // Backward compatible: plain integer → uniform padding
    if let intVal = raw.int {
        let unit = AccordionPaddingUnit.absolute(intVal)
        return AccordionPadding(horizontal: .constant(unit), vertical: .constant(unit))
    }
    // String value at top level (e.g. accordion-padding = "15%")
    if let strVal = raw.string {
        if let unit = parsePercentString(strVal) {
            return AccordionPadding(horizontal: .constant(unit), vertical: .constant(unit))
        } else {
            errors.append(.semantic(backtrace, "Can't parse accordion-padding value '\(strVal)'. Expected an integer or a percentage string like '15%'"))
            return .default
        }
    }
    // Table → per-axis parsing
    return parseTable(raw, .default, accordionPaddingAxisParser, backtrace, &errors)
}

func parseAccordionPaddingUnit(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> AccordionPaddingUnit? {
    if let intVal = raw.int {
        return .absolute(intVal)
    }
    if let strVal = raw.string {
        if let unit = parsePercentString(strVal) {
            return unit
        }
        errors.append(.semantic(backtrace, "Can't parse accordion-padding value '\(strVal)'. Expected an integer or a percentage string like '15%'"))
        return nil
    }
    errors.append(.semantic(backtrace, "Expected type is 'integer' or 'string'. But actual type is '\(raw.type)'"))
    return nil
}

private func parsePercentString(_ str: String) -> AccordionPaddingUnit? {
    let trimmed = str.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasSuffix("%") else { return nil }
    let numberPart = String(trimmed.dropLast())
    guard let value = Double(numberPart) else { return nil }
    return .percent(value)
}

// MARK: - DynamicConfigValue support for AccordionPaddingUnit

func parseDynamicValue(
    _ raw: TOMLValueConvertible,
    _ valueType: AccordionPaddingUnit.Type,
    _ fallback: AccordionPaddingUnit,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
    _ parseUnit: (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> AccordionPaddingUnit?,
) -> DynamicConfigValue<AccordionPaddingUnit> {
    // Simple value (int or string)
    if let unit = parseUnit(raw, backtrace, &errors) {
        return .constant(unit)
    }
    // If parseUnit already appended errors for a non-array type, and this isn't an array, return fallback
    if raw.array == nil {
        return .constant(fallback)
    }
    // Clear errors from the failed parseUnit attempt since we're now parsing as array
    // The parseUnit call above would have added an error for the array type
    if let lastError = errors.last,
       case .semantic(_, let msg) = lastError,
       msg.contains("Expected type is")
    {
        errors.removeLast()
    }

    let array = raw.array!
    if array.isEmpty {
        errors.append(.semantic(backtrace, "The array must not be empty"))
        return .constant(fallback)
    }

    // Last element is the default value
    var defaultErrors: [TomlParseError] = []
    guard let defaultValue = parseUnit(array.last!, backtrace, &defaultErrors) else {
        errors.append(.semantic(backtrace, "The last item in the array must be a valid accordion-padding value"))
        return .constant(fallback)
    }

    if array.dropLast().isEmpty {
        errors.append(.semantic(backtrace, "The array must contain at least one monitor pattern"))
        return .constant(fallback)
    }

    let rules: [PerMonitorValue<AccordionPaddingUnit>] = parsePerMonitorAccordionValues(
        TOMLArray(array.dropLast()), backtrace, &errors, parseUnit,
    )

    return .perMonitor(rules, default: defaultValue)
}

private func parsePerMonitorAccordionValues(
    _ array: TOMLArray,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
    _ parseUnit: (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> AccordionPaddingUnit?,
) -> [PerMonitorValue<AccordionPaddingUnit>] {
    array.enumerated().compactMap { (index: Int, raw: TOMLValueConvertible) -> PerMonitorValue<AccordionPaddingUnit>? in
        var backtrace = backtrace + .index(index)

        guard let (key, value) = raw.unwrapTableWithSingleKey(expectedKey: "monitor", &backtrace)
            .flatMap({ $0.value.unwrapTableWithSingleKey(expectedKey: nil, &backtrace) })
            .getOrNil(appendErrorTo: &errors)
        else {
            return nil
        }

        let monitorDescriptionResult = parseMonitorDescription(key, backtrace)
        guard let monitorDescription = monitorDescriptionResult.getOrNil(appendErrorTo: &errors) else { return nil }

        guard let unit = parseUnit(value, backtrace, &errors) else { return nil }

        return PerMonitorValue(description: monitorDescription, value: unit)
    }
}
