import Common

struct Gaps: ConvenienceCopyable, Equatable, Sendable {
    var inner: Inner
    var outer: Outer

    static let zero = Gaps(inner: .zero, outer: .zero)

    struct Inner: ConvenienceCopyable, Equatable, Sendable {
        var vertical: DynamicConfigValue<Int>
        var horizontal: DynamicConfigValue<Int>

        static let zero = Inner(vertical: 0, horizontal: 0)

        init(vertical: Int, horizontal: Int) {
            self.vertical = .constant(vertical)
            self.horizontal = .constant(horizontal)
        }

        init(vertical: DynamicConfigValue<Int>, horizontal: DynamicConfigValue<Int>) {
            self.vertical = vertical
            self.horizontal = horizontal
        }
    }

    struct Outer: ConvenienceCopyable, Equatable, Sendable {
        var left: DynamicConfigValue<Int>
        var bottom: DynamicConfigValue<Int>
        var top: DynamicConfigValue<Int>
        var right: DynamicConfigValue<Int>

        static let zero = Outer(left: 0, bottom: 0, top: 0, right: 0)

        init(left: Int, bottom: Int, top: Int, right: Int) {
            self.left = .constant(left)
            self.bottom = .constant(bottom)
            self.top = .constant(top)
            self.right = .constant(right)
        }

        init(left: DynamicConfigValue<Int>, bottom: DynamicConfigValue<Int>, top: DynamicConfigValue<Int>, right: DynamicConfigValue<Int>) {
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
            vertical: gaps.inner.vertical.getValue(for: monitor),
            horizontal: gaps.inner.horizontal.getValue(for: monitor),
        )

        outer = .init(
            left: gaps.outer.left.getValue(for: monitor),
            bottom: gaps.outer.bottom.getValue(for: monitor),
            top: gaps.outer.top.getValue(for: monitor),
            right: gaps.outer.right.getValue(for: monitor),
        )
    }
}

private let gapsParser: [String: any ParserProtocol<Gaps>] = [
    "inner": Parser(\.inner, parseInner),
    "outer": Parser(\.outer, parseOuter),
]

private let innerParser: [String: any ParserProtocol<Gaps.Inner>] = [
    "vertical": Parser(\.vertical, parseIntDynamicValue),
    "horizontal": Parser(\.horizontal, parseIntDynamicValue),
]

private let outerParser: [String: any ParserProtocol<Gaps.Outer>] = [
    "left": Parser(\.left, parseIntDynamicValue),
    "bottom": Parser(\.bottom, parseIntDynamicValue),
    "top": Parser(\.top, parseIntDynamicValue),
    "right": Parser(\.right, parseIntDynamicValue),
]

private func parseIntDynamicValue(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> DynamicConfigValue<Int> {
    parseDynamicValue(raw, ofType: Int.self, 0, backtrace, &errors)
}

func parseGaps(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> Gaps {
    parseTable(raw, .zero, gapsParser, backtrace, &errors)
}

func parseInner(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> Gaps.Inner {
    parseTable(raw, Gaps.Inner.zero, innerParser, backtrace, &errors)
}

func parseOuter(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> Gaps.Outer {
    parseTable(raw, Gaps.Outer.zero, outerParser, backtrace, &errors)
}
