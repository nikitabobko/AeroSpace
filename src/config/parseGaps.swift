import Common
import TOMLKit

private let gapsParser: [String: any ParserProtocol<Gaps>] = [
    "inner": Parser(\.inner, parseInner),
    "outer": Parser(\.outer, parseOuter),
]

private let innerParser: [String: any ParserProtocol<Gaps.Inner>] = [
    "vertical": Parser(\.vertical) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) },
    "horizontal": Parser(\.horizontal) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) },
]

private let outerParser: [String: any ParserProtocol<Gaps.Outer>] = [
    "left": Parser(\.left) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) },
    "bottom": Parser(\.bottom) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) },
    "top": Parser(\.top) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) },
    "right": Parser(\.right) { value, backtrace, errors in parseDynamicValue(value, Int.self, 0, backtrace, &errors) },
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
