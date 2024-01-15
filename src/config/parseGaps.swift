import Common
import TOMLKit

private let gapsParser: [String: any ParserProtocol<RawGaps>] = [
    "inner": Parser(\.inner, parseInner),
    "outer": Parser(\.outer, parseOuter)
]

private let innerParser: [String: any ParserProtocol<RawInner>] = [
    "vertical": Parser(\.vertical) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) },
    "horizontal": Parser(\.horizontal) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) }
]

private let outerParser: [String: any ParserProtocol<RawOuter>] = [
    "left": Parser(\.left) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) },
    "bottom": Parser(\.bottom) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) },
    "top": Parser(\.top) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) },
    "right": Parser(\.right) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) }
]

func parseGaps(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Gaps {
    let raw = parseTable(raw, RawGaps(), gapsParser, backtrace, &errors)
    return Gaps(inner: raw.inner ?? .zero, outer: raw.outer ?? .zero)
}

func parseInner(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Gaps.Inner {
    let raw = parseTable(raw, RawInner(), innerParser, backtrace, &errors)
    return Gaps.Inner(
        vertical: raw.vertical ?? .constant(0),
        horizontal: raw.horizontal ?? .constant(0)
    )
}

func parseOuter(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Gaps.Outer {
    let raw = parseTable(raw, RawOuter(), outerParser, backtrace, &errors)
    return Gaps.Outer(
        left: raw.left ?? .constant(0),
        bottom: raw.bottom ?? .constant(0),
        top: raw.top ?? .constant(0),
        right: raw.right ?? .constant(0)
    )
}

private struct RawGaps: Copyable {
    var inner: Gaps.Inner?
    var outer: Gaps.Outer?
}

private struct RawInner: Copyable {
    var vertical: DynamicConfigValue<Int>?
    var horizontal: DynamicConfigValue<Int>?
}

private struct RawOuter: Copyable {
    var left: DynamicConfigValue<Int>?
    var bottom: DynamicConfigValue<Int>?
    var top: DynamicConfigValue<Int>?
    var right: DynamicConfigValue<Int>?
}
