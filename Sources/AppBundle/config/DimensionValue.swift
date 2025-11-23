import AppKit
import Common

/// Represents a dimension value that can be either pixels or percentage
public enum DimensionValue: Equatable, Sendable {
    case pixels(Int)
    case percentage(Int)

    /// Resolves the value to pixels based on the given total dimension
    func toPixels(totalDimension: CGFloat) -> Int {
        switch self {
            case .pixels(let px):
                return px
            case .percentage(let pct):
                return Int(totalDimension * CGFloat(pct) / 100.0)
        }
    }

    /// Parses a string value into DimensionValue
    /// Accepts formats: "10" (pixels), "10%" (percentage)
    static func parse(_ str: String) -> DimensionValue? {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        if trimmed.hasSuffix("%") {
            let valueStr = trimmed.dropLast()
            if let value = Int(valueStr), value >= 0, value <= 100 {
                return .percentage(value)
            }
        } else if let value = Int(trimmed), value >= 0 {
            return .pixels(value)
        }

        return nil
    }
}

extension DimensionValue: CustomStringConvertible {
    public var description: String {
        switch self {
            case .pixels(let px):
                return "\(px)"
            case .percentage(let pct):
                return "\(pct)%"
        }
    }
}
