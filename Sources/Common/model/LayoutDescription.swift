public enum LayoutDescription: String, CaseIterable, Equatable, Sendable {
    case accordion, tiles
    case horizontal, vertical
    case h_accordion, v_accordion, h_tiles, v_tiles
    case tiling, floating
}

extension LayoutDescription {
    public static var unionLiteral: String {
        "(\(LayoutDescription.allCases.map(\.rawValue).joined(separator: "|")))"
    }
}

public func parseLayoutDescription(_ value: String) -> LayoutDescription? {
    if let parsed = LayoutDescription(rawValue: value) {
        return parsed
    } else if value == "list" {
        return .tiles
    } else if value == "h_list" {
        return .h_tiles
    } else if value == "v_list" {
        return .v_tiles
    }
    return nil
}
