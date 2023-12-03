import TOMLKit

private let gapsParser: [String: any ParserProtocol<RawGaps>] = [
    "inner": Parser(\.inner, parseInner),
    "outer": Parser(\.outer, parseOuter),
]

private let innerParser: [String: any ParserProtocol<RawInner>] = [
    "vertical": Parser(\.vertical, parseInt),
    "horizontal": Parser(\.horizontal, parseInt),
]

private let outerParser: [String: any ParserProtocol<RawOuter>] = [
    "left": Parser(\.left, parseInt),
    "bottom": Parser(\.bottom, parseInt),
    "top": Parser(\.top, parseInt),
    "right": Parser(\.right, parseInt),
]

func parseGaps(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Gaps {
    let raw = parseTable(raw, RawGaps(), gapsParser, backtrace, &errors)
    return Gaps(inner: raw.inner ?? .zero, outer: raw.outer ?? .zero)
}

func parseInner(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Gaps.Inner {
    let raw = parseTable(raw, RawInner(), innerParser, backtrace, &errors)
    return Gaps.Inner(vertical: raw.vertical ?? 0, horizontal: raw.horizontal ?? 0)
}

func parseOuter(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Gaps.Outer {
    let raw = parseTable(raw, RawOuter(), outerParser, backtrace, &errors)
    return Gaps.Outer(left: raw.left ?? 0, bottom: raw.bottom ?? 0, top: raw.top ?? 0, right: raw.right ?? 0)
}

private struct RawGaps: Copyable {
    var inner: Gaps.Inner?
    var outer: Gaps.Outer?
}

private struct RawInner: Copyable {
    var vertical: Int?
    var horizontal: Int?
}

private struct RawOuter: Copyable {
    var left: Int?
    var bottom: Int?
    var top: Int?
    var right: Int?
}
