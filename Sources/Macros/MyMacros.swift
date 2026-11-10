import Foundation

// Speaks the compiler plugin protocol directly (to optimize compilation speed). Don't depend on swift-syntax (for now)
// See swift-syntax's PluginMessages.swift
// https://github.com/swiftlang/swift-syntax
// https://github.com/swiftlang/swift-syntax/issues/2421
@main
struct AeroSpaceMacrosPlugin {
    static func main() throws {
        while let request = try readMessage() {
            try writeMessage(response(for: JSONDecoder().decode(HostToPluginMessage.self, from: request)))
        }
    }
}

private func response(for message: HostToPluginMessage) -> PluginToHostMessage {
    switch message {
        case .getCapability:
            return .getCapabilityResult(capability: PluginCapability(protocolVersion: 8))
        case .expandFreestandingMacro(let macro):
            let file = switch macro.typeName {
                case "FileIdMacro": "#fileID"
                case "FilePathMacro": "#filePath"
                default: fatalError("Unknown macro \(macro.typeName)")
            }
            return .expandMacroResult(
                expandedSource: "MyFileId.init(file: \(file), line: #line, column: #column, function: #function)",
                diagnostics: [],
            )
    }
}

private enum HostToPluginMessage: Decodable {
    case getCapability
    case expandFreestandingMacro(macro: MacroReference)
}

private struct MacroReference: Decodable {
    var typeName: String
}

private enum PluginToHostMessage: Encodable {
    case getCapabilityResult(capability: PluginCapability)
    case expandMacroResult(expandedSource: String, diagnostics: [String])
}

private struct PluginCapability: Encodable {
    // periphery:ignore - Encodable
    var protocolVersion: Int
}

private func readMessage() throws -> Data? {
    guard let header = try FileHandle.standardInput.read(upToCount: 8), header.count == 8 else { return nil }
    let count = header.reversed().reduce(0) { $0 << 8 | Int($1) }
    return try FileHandle.standardInput.read(upToCount: count) ?? Data()
}

private func writeMessage(_ message: PluginToHostMessage) throws {
    let payload = try JSONEncoder().encode(message)
    let header = (0 ..< 8).map { UInt8(truncatingIfNeeded: UInt64(payload.count) >> (8 * $0)) }
    try FileHandle.standardOutput.write(contentsOf: Data(header) + payload)
}
