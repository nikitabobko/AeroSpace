import AppKit
import Common

enum Json: Encodable, Equatable {
    // vector
    case dict(JsonDict)
    case array(JsonArray)

    // scalar
    case null
    case string(String)
    case int(Int64)
    case bool(Bool)

    typealias JsonDict = [String: Json]
    typealias JsonArray = [Json]

    func encode(to encoder: any Encoder) throws {
        switch self {
            case .array(let value): try value.encode(to: encoder)
            case .dict(let value): try value.encode(to: encoder)
            case .string(let value): try value.encode(to: encoder)
            case .int(let value): try value.encode(to: encoder)
            case .bool(let value): try value.encode(to: encoder)
            case .null: try (nil as String?).encode(to: encoder)
        }
    }

    static func newOrDieRecursive(_ value: Any?) -> Json {
        switch value {
            case let value as [String: Any?]: .dict(value.mapValues(newOrDieRecursive))
            case let value as [Any?]: .array(value.map(newOrDieRecursive))
            default:
                newScalarOrNil(value)
                    ?? dieT("Can't parse \(String(describing: value)) (\(Swift.type(of: value))) to JSON")
        }
    }

    static func newScalarOrNil(_ value: Any?) -> Json? {
        switch value {
            case let value as Int64: .int(value)
            case let value as Int: .int(Int64(value))
            case let value as UInt32: .int(Int64(value))
            case let value as UInt: .int(Int64(value))
            case let value as Bool: .bool(value)
            case let value as String: .string(value)
            case nil, is NSNull: .null
            default: nil
        }
    }

    static func stringOrNull(_ str: String?) -> Json { str.map(Json.string) ?? .null }

    static func int(_ int: Int) -> Json { .int(Int64(exactly: int).orDie()) }
    static func int(_ int: UInt32) -> Json { .int(Int64(exactly: int).orDie()) }

    var rawValue: Any? {
        switch self {
            case .null: nil

            case .array(let x): x
            case .dict(let x): x

            case .bool(let x): x
            case .int(let x): x
            case .string(let x): x
        }
    }

    var asDictOrDie: [String: Json] { asDictOrNil.orDie("\(self) is not a dict") }

    var asInt64OrNil: Int64? {
        if case .int(let value) = self { value } else { nil }
    }

    var asIntOrNil: Int? {
        asInt64OrNil.flatMap { Int.init(exactly: $0) }
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
    case bool
}
