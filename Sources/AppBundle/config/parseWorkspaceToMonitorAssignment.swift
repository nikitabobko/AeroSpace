import Common
import TOMLKit

func parseWorkspaceToMonitorAssignment(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [String: [MonitorDescription]] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: [MonitorDescription]] = [:]
    for (workspaceName, rawMonitorDescription) in rawTable {
        result[workspaceName] = parseMonitorDescriptions(rawMonitorDescription, backtrace + .key(workspaceName), &errors)
    }
    return result
}

func parseMonitorDescriptions(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [MonitorDescription] {
    if let array = raw.array {
        return array.enumerated()
            .map { (index, rawDesc) in parseMonitorDescription(rawDesc, backtrace + .index(index)).getOrNil(appendErrorTo: &errors) }
            .filterNotNil()
    } else {
        return parseMonitorDescription(raw, backtrace).getOrNil(appendErrorTo: &errors).asList()
    }
}

func parseMonitorDescription(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<MonitorDescription> {
    // Check if it's a table (fingerprint pattern)
    if let table = raw.table {
        if let fingerprintTable = table["fingerprint"]?.table {
            return parseFingerprintPattern(fingerprintTable, backtrace + .key("fingerprint"))
        } else {
            return .failure(.semantic(backtrace, "Table monitor description must contain 'fingerprint' key"))
        }
    }
    
    // Otherwise parse as string/int
    let rawString: String
    if let string = raw.string {
        rawString = string
    } else if let int = raw.int {
        rawString = String(int)
    } else {
        return .failure(expectedActualTypeError(expected: [.string, .int, .table], actual: raw.type, backtrace))
    }

    return parseMonitorDescription(rawString).toParsedToml(backtrace)
}

private func parseFingerprintPattern(_ table: TOMLTable, _ backtrace: TomlBacktrace) -> ParsedToml<MonitorDescription> {
    var vendorID: UInt32?
    var modelID: UInt32?
    var serialNumber: String?
    var displayNamePattern: String?
    var widthPixels: Int?
    var heightPixels: Int?
    
    for (key, value) in table {
        let keyBacktrace = backtrace + .key(key)
        switch key {
        case "vendor", "vendor_id", "vendorID":
            if let int = value.int {
                vendorID = UInt32(int)
            } else if let string = value.string, string.hasPrefix("0x") || string.hasPrefix("0X") {
                vendorID = UInt32(string.dropFirst(2), radix: 16)
            } else {
                return .failure(.semantic(keyBacktrace, "vendor_id must be an integer or hex string (e.g., '0x1234')"))
            }
        case "model", "model_id", "modelID":
            if let int = value.int {
                modelID = UInt32(int)
            } else if let string = value.string, string.hasPrefix("0x") || string.hasPrefix("0X") {
                modelID = UInt32(string.dropFirst(2), radix: 16)
            } else {
                return .failure(.semantic(keyBacktrace, "model_id must be an integer or hex string (e.g., '0x5678')"))
            }
        case "serial", "serial_number", "serialNumber":
            guard let string = value.string else {
                return .failure(expectedActualTypeError(expected: .string, actual: value.type, keyBacktrace))
            }
            serialNumber = string
        case "name", "display_name", "displayName":
            guard let string = value.string else {
                return .failure(expectedActualTypeError(expected: .string, actual: value.type, keyBacktrace))
            }
            displayNamePattern = string
        case "width", "width_pixels", "widthPixels":
            guard let int = value.int else {
                return .failure(expectedActualTypeError(expected: .int, actual: value.type, keyBacktrace))
            }
            widthPixels = int
        case "height", "height_pixels", "heightPixels":
            guard let int = value.int else {
                return .failure(expectedActualTypeError(expected: .int, actual: value.type, keyBacktrace))
            }
            heightPixels = int
        default:
            return .failure(unknownKeyError(keyBacktrace))
        }
    }
    
    let patternData = MonitorFingerprintPatternData(
        vendorID: vendorID,
        modelID: modelID,
        serialNumber: serialNumber,
        displayNamePattern: displayNamePattern,
        widthPixels: widthPixels,
        heightPixels: heightPixels
    )
    
    return .success(.fingerprint(patternData))
}
