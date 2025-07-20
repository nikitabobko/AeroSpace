import Foundation

extension JSONEncoder {
    public static var aeroSpaceDefault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        return encoder
    }

    public func encodeToString(_ value: Encodable) -> String? {
        guard let data = Result(catching: { try encode(value) }).getOrNil() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
