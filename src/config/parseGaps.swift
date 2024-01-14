import Common
import TOMLKit

private let gapsParser: [String: any ParserProtocol<RawGaps>] = [
    "inner-vertical": Parser(\.innerVertical) { value, backtrace in
        parseDynamicValue(value, Int.self, backtrace)
    },
    "inner-horizontal": Parser(\.innerHorizontal) { value, backtrace in
        parseDynamicValue(value, Int.self, backtrace)
    },
    "outer-left": Parser(\.outerLeft) { value, backtrace in
        parseDynamicValue(value, Int.self, backtrace)
    },
    "outer-right": Parser(\.outerRight) { value, backtrace in
        parseDynamicValue(value, Int.self, backtrace)
    },
    "outer-top": Parser(\.outerTop) { value, backtrace in
        parseDynamicValue(value, Int.self, backtrace)
    },
    "outer-bottom": Parser(\.outerBottom) { value, backtrace in
        parseDynamicValue(value, Int.self, backtrace)
    }
]

func parseGaps(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> Gaps {
    let raw = parseTable(raw, RawGaps(), gapsParser, backtrace, &errors)
    return Gaps(
        inner: .init(
            vertical: raw.innerVertical ?? .constant(0),
            horizontal: raw.innerHorizontal ?? .constant(0)
        ),
        outer: .init(
            left: raw.outerLeft ?? .constant(0),
            bottom: raw.outerBottom ?? .constant(0),
            top: raw.outerTop ?? .constant(0),
            right: raw.outerRight ?? .constant(0)
        )
    )
}

private struct RawGaps: Copyable {
    var innerVertical: DynamicConfigValue<Int>?
    var innerHorizontal: DynamicConfigValue<Int>?
    var outerLeft: DynamicConfigValue<Int>?
    var outerRight: DynamicConfigValue<Int>?
    var outerTop: DynamicConfigValue<Int>?
    var outerBottom: DynamicConfigValue<Int>?
}
