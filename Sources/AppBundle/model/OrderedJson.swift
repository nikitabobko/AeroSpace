import AppKit
import Common
import OrderedCollections

enum OrderedJson: Encodable, Equatable { // todo rename to Dto (data transfer object)
    // vector
    case dict(JsonDict)
    case array(JsonArray)

    // scalar
    case null
    case string(String)
    case int(Int64)
    case bool(Bool)

    typealias JsonDict = OrderedDictionary<String, OrderedJson>
    typealias JsonArray = [OrderedJson]

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

    static func newScalarOrNil(_ value: Any?) -> OrderedJson? {
        guard let dto = Json.newScalarOrNil(value) else { return nil }
        return switch dto {
            case .array: dieT("array is not scalar")
            case .dict: dieT("dict is not scalar")

            case .bool(let bool): .bool(bool)
            case .int(let int): .int(int)
            case .string(let string): .string(string)
            case .null: .null
        }
    }

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
    case table = "Table"
    case array = "Array"

    case null = "Null"
    case string = "String"
    case int = "Int"
    case bool = "Bool"
}
