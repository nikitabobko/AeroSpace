import Common
import Foundation

enum Json: Encodable {
    // vector
    case dict([String: Json])
    case array([Json])

    // scalar
    case null
    case string(String)
    case int(Int)
    case uint32(UInt32)
    case bool(Bool)

    func encode(to encoder: any Encoder) throws {
        switch self {
            case .array(let value): try value.encode(to: encoder)
            case .dict(let value): try value.encode(to: encoder)
            case .string(let value): try value.encode(to: encoder)
            case .int(let value): try value.encode(to: encoder)
            case .uint32(let value): try value.encode(to: encoder)
            case .bool(let value): try value.encode(to: encoder)
            case .null: try (nil as String?).encode(to: encoder)
        }
    }

    static func fromOrDie(_ value: Any?) -> Json {
        if let value = value as? [String: Any] {
            return .dict(value.mapValues(fromOrDie))
        } else if let value = value as? [Any] {
            return .array(value.map(fromOrDie))
        } else if let value = value as? Int {
            return .int(value)
        } else if let value = value as? UInt32 {
            return .uint32(value)
        } else if let value = value as? Bool {
            return .bool(value)
        } else if let value = value as? String {
            return .string(value)
        } else if value == nil || value is NSNull {
            return .null
        } else {
            die("Can't parse \(String(describing: value)) (\(type(of: value))) to JSON")
        }
    }
}
