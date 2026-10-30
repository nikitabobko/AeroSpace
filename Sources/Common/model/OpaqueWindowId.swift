public struct OpaqueWindowId: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawId: UInt64
    public init(_ id: UInt64) { self.rawId = id }

    @MainActor private static var globalId: UInt64 = 0
    @MainActor public static func nextUniqId() -> Self {
        globalId += 1
        return .init(globalId)
    }

    public /*confroms*/ var description: String { rawId.description }

    public /*confroms*/ init(from decoder: any Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(UInt64.self))
    }

    public /*confroms*/ func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawId)
    }
}
