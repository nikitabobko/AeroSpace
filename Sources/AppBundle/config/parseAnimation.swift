import Common
import Foundation

struct AnimationConfig: ConvenienceCopyable, Equatable, Sendable {
    var enabled: Bool
    /// Animation duration in milliseconds. Reasonable range: 30-500.
    var durationMs: Int
    /// Target frames per second for the interpolation. Reasonable range: 30-240.
    /// Note: actual achieved fps depends on how fast the target app responds to AX size/position requests.
    var fps: Int
    /// Easing curve to apply to the interpolation parameter t in [0, 1].
    var easing: AnimationEasing

    static let `default` = AnimationConfig(
        enabled: true,
        durationMs: 150,
        fps: 120,
        easing: .easeOutCubic,
    )

    /// Effective frame interval in seconds, derived from `fps`.
    var frameIntervalSec: Double { 1.0 / Double(max(1, fps)) }
    /// Effective duration in seconds.
    var durationSec: Double { Double(max(0, durationMs)) / 1000.0 }
}

enum AnimationEasing: String, Sendable {
    case linear
    case easeOutCubic = "ease-out-cubic"
    case easeInOutCubic = "ease-in-out-cubic"

    func apply(_ t: Double) -> Double {
        let clamped = t < 0 ? 0 : (t > 1 ? 1 : t)
        switch self {
            case .linear:
                return clamped
            case .easeOutCubic:
                let inv = 1 - clamped
                return 1 - inv * inv * inv
            case .easeInOutCubic:
                return clamped < 0.5
                    ? 4 * clamped * clamped * clamped
                    : 1 - pow(-2 * clamped + 2, 3) / 2
        }
    }
}

private let animationParser: [String: any ParserProtocol<AnimationConfig>] = [
    "enabled": Parser(\.enabled, parseBool),
    "duration-ms": Parser(\.durationMs) { raw, backtrace in
        parseInt(raw, backtrace).filter(.semantic(backtrace, "Must be in [0, 5000] range")) { (0 ... 5000).contains($0) }
    },
    "fps": Parser(\.fps) { raw, backtrace in
        parseInt(raw, backtrace).filter(.semantic(backtrace, "Must be in [1, 480] range")) { (1 ... 480).contains($0) }
    },
    "easing": Parser(\.easing) { raw, backtrace in
        parseString(raw, backtrace).flatMap {
            AnimationEasing(rawValue: $0).orFailure(.semantic(backtrace, "Can't parse animation easing '\($0)'. Possible values: linear, ease-out-cubic, ease-in-out-cubic"))
        }
    },
]

func parseAnimation(_ raw: Json, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseError]) -> AnimationConfig {
    parseTable(raw, .default, animationParser, backtrace, &errors)
}
