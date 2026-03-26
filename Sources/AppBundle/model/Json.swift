import AppKit
import Common

enum Json: Encodable, Equatable {
    // vector
    case dict(JsonDict)
    case array(JsonArray)

    // scalar
    case null
    case string(String)
    case int(Int)
    case uint32(UInt32)
    case bool(Bool)

    typealias JsonDict = [String: Json]
    typealias JsonArray = [Json]

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

    static func newOrDie(_ value: Any?) -> Json {
        if let value = value as? [String: Any?] {
            return .dict(value.mapValues(newOrDie))
        } else if let value = value as? [Any?] {
            return .array(value.map(newOrDie))
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
            die("Can't parse \(String(describing: value)) (\(Swift.type(of: value))) to JSON")
        }
    }

    static func stringOrNull(_ str: String?) -> Json { str.map(Json.string) ?? .null }

    var rawValue: Any? {
        switch self {
            case .null: nil

            case .array(let x): x
            case .dict(let x): x

            case .bool(let x): x
            case .int(let x): x
            case .string(let x): x
            case .uint32(let x): x
        }
    }

    var asDictOrDie: [String: Json] { asDictOrNil.orDie("\(self) is not a dict") }

    var asIntOrNil: Int? {
        if case .int(let value) = self { value } else { nil }
    }

    var asStringOrNil: String? {
        if case .string(let value) = self { value } else { nil }
    }

    var asBoolOrNil: Bool? {
        if case .bool(let value) = self { value } else { nil }
    }

    var asDictOrNil: JsonDict? {
        if case .dict(let value) = self { value } else { nil }
    }

    var asArrayOrNil: JsonArray? {
        if case .array(let value) = self { value } else { nil }
    }

    var tomlType: TomlType {
        switch self {
            case .dict: return .table
            case .array: return .array
            case .null: return .null
            case .string: return .string
            case .int: return .int
            case .uint32: return .uint32
            case .bool: return .bool
        }
    }
}

enum TomlType: String {
    case table
    case array

    case null
    case string
    case int
    case uint32
    case bool
}
