import AppKit
import Common

struct CommandCenterConfig: Withable, Equatable, Sendable {
    var backgroundColor = ArgbColor(0xCC00_0000)
    var workspaceColor = ArgbColor(0xFF1E_1E1E)
    var hoverColor = ArgbColor(0xFF26_2626)
    var windowColor = ArgbColor(0xFF2E_2E2E)
    var activeColor = ArgbColor(0xFFE2_E2E3)
    var visibleColor = ArgbColor(0xFF8C_8C8C)
    var inactiveColor = ArgbColor(0xFF3A_3A3A)
    var textColor = ArgbColor(0xFFE2_E2E3)
    var jankyBorders = true
}

/// Color in `0xAARRGGBB` format (the same format JankyBorders uses)
struct ArgbColor: Equatable, Sendable {
    let argb: UInt32

    init(_ argb: UInt32) { self.argb = argb }

    static func parse(_ raw: String) -> ResOrStr<ArgbColor> {
        let hex = raw.removePrefix("0x").removePrefix("0X").removePrefix("#")
        guard hex.count == 8, let argb = UInt32(hex, radix: 16) else {
            return .failure("Can't parse color \(raw.singleQuoted). Expected format: 0xAARRGGBB")
        }
        return .success(ArgbColor(argb))
    }

    var nsColor: NSColor {
        NSColor(
            srgbRed: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255,
        )
    }

    /// Whether dark text reads better on this color than light text
    var isLight: Bool {
        let r = Double((argb >> 16) & 0xFF), g = Double((argb >> 8) & 0xFF), b = Double(argb & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.6
    }
}

private let commandCenterParserTable: [String: any ParserProtocol<CommandCenterConfig>] = [
    "background-color": Parser(\.backgroundColor, parseColor),
    "workspace-color": Parser(\.workspaceColor, parseColor),
    "hover-color": Parser(\.hoverColor, parseColor),
    "window-color": Parser(\.windowColor, parseColor),
    "active-color": Parser(\.activeColor, parseColor),
    "visible-color": Parser(\.visibleColor, parseColor),
    "inactive-color": Parser(\.inactiveColor, parseColor),
    "text-color": Parser(\.textColor, parseColor),
    "jankyborders": Parser(\.jankyBorders, parseBool),
]

func parseCommandCenter(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> CommandCenterConfig {
    parseNonEmptyTable(raw, CommandCenterConfig(), commandCenterParserTable, backtrace, &c)
}

private func parseColor(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<ArgbColor> {
    if let int = raw.asInt64OrNil {
        return UInt32(exactly: int).map(ArgbColor.init)
            .toResult(.init(backtrace, "Color must be in [0x00000000, 0xFFFFFFFF] range. Got: \(int)"))
    }
    if let str = raw.asStringOrNil {
        return ArgbColor.parse(str).mapError { .init(backtrace, $0) }
    }
    return .failure(.init(backtrace, expectedActualTypeError(expected: [.int, .string], actual: raw.tomlType)))
}
