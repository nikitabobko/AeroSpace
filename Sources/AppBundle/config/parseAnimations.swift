import Common

struct AnimationsConfig: Withable, Equatable, Sendable {
    var resizeDurationMs: Int = 0
    var fullscreenDurationMs: Int = 0
    var workspaceSlideDurationMs: Int = 0
    var easing: Easing = .easeOut
}

enum Easing: String, Equatable, Sendable, CaseIterable {
    case linear
    case easeOut = "ease-out"
    case easeInOut = "ease-in-out"
}

let animationDurationMsRange: ClosedRange<Int> = 0 ... 1000

private let animationsParser: [String: any ParserProtocol<AnimationsConfig>] = [
    "resize-duration-ms": Parser(\.resizeDurationMs, parseAnimationDurationMs),
    "fullscreen-duration-ms": Parser(\.fullscreenDurationMs, parseAnimationDurationMs),
    "workspace-slide-duration-ms": Parser(\.workspaceSlideDurationMs, parseAnimationDurationMs),
    "easing": Parser(\.easing, parseEasing),
]

func parseAnimations(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> AnimationsConfig {
    parseNonEmptyTable(raw, AnimationsConfig(), animationsParser, backtrace, &c)
}

private func parseAnimationDurationMs(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<Int> {
    parseInt(raw, backtrace).flatMap { value in
        animationDurationMsRange.contains(value)
            ? .success(value)
            : .failure(.init(
                backtrace,
                "Animation duration must be in [\(animationDurationMsRange.lowerBound), \(animationDurationMsRange.upperBound)] range (milliseconds). But got: \(value)",
            ))
    }
}

private func parseEasing(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<Easing> {
    parseString(raw, backtrace).flatMap { value in
        Easing(rawValue: value).toResult(.init(
            backtrace,
            "Can't parse easing '\(value)'. Possible values: \(Easing.allCases.map(\.rawValue).joined(separator: ", "))",
        ))
    }
}
