import AppKit
import Common

func dumpAxRecursive(_ ax: AXUIElement, _ kind: AxKind, recursionDepth: Int = 0) -> [String: Json] {
    if recursionDepth > 5 {
        return [
            "dumpAxRecursive infinite recursion": .bool(true),
            kAXAeroSynthetic: .bool(true),
        ]
    }
    let recursionDepth = recursionDepth + 1
    var result: [String: Json] = [:]
    var ignored: [String] = []
    var writable: [String] = []
    var failedAxRequest: [String] = []
    for key: String in ax.attrs(failedAxRequest: &failedAxRequest).sortedBy({ priorityAx.contains($0) ? 0 : 1 }) {
        if globalIgnore.contains(key) || kindSpecificIgnore[kind]?.contains(key) == true {
            ignored.append(key)
        } else {
            var raw: AnyObject?
            if AXUIElementCopyAttributeValue(ax, key as CFString, &raw) != .success {
                failedAxRequest.append("get.\(key)")
            }
            result[key] = prettyValue(raw as Any?, recursionDepth: recursionDepth)

            var isWritable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(ax, key as CFString, &isWritable) != .success {
                failedAxRequest.append("isWritable.\(key)")
            }
            if isWritable.boolValue { writable.append(key) }
        }
    }
    if !writable.isEmpty { result["Aero.AxWritable"] = .string(writable.joined(separator: ", ")) }
    if !failedAxRequest.isEmpty { result["Aero.AxFailed"] = .string(failedAxRequest.joined(separator: ", ")) }
    if !ignored.isEmpty { result["Aero.AxIgnored"] = .string(ignored.joined(separator: ", ")) }
    return result
}

enum AxKind: Hashable {
    case button
    case window
    case app
}

private func prettyValue(_ value: Any?, recursionDepth: Int) -> Json {
    if let arr = value as? [Any?] {
        return .array(arr.map { prettyValue($0, recursionDepth: recursionDepth) })
    }
    if let value = value as? Int {
        return .int(value)
    }
    if let value = value as? UInt32 {
        return .uint32(value)
    }
    if let value = value as? Bool {
        return .bool(value)
    }
    if let value {
        let ax = value as! AXUIElement
        if ax.get(Ax.roleAttr) == kAXButtonRole {
            return .dict(dumpAxRecursive(ax, .button, recursionDepth: recursionDepth))
        }
        if let windowId = ax.containingWindowId() {
            let title = ax.get(Ax.titleAttr)?.doubleQuoted ?? "nil"
            let role = ax.get(Ax.roleAttr)?.doubleQuoted ?? "nil"
            let subrole = ax.get(Ax.subroleAttr)?.doubleQuoted ?? "nil"
            return .string("AXUIElement(AxWindowId=\(windowId), title=\(title), role=\(role), subrole=\(subrole))")
        }
        return .string(String(describing: value))
    }
    return .null
}

extension AXUIElement {
    fileprivate func attrs(failedAxRequest: inout [String]) -> [String] {
        var rawArray: CFArray?
        if AXUIElementCopyAttributeNames(self, &rawArray) != .success {
            failedAxRequest.append("AXUIElementCopyAttributeNames")
        }
        return rawArray as? [String] ?? []
    }
}

private let globalIgnore: Set<String> = [
    "AXChildren", // too verbose
    "AXChildrenInNavigationOrder", // too verbose
    "AXFocusableAncestor", // infinite recursion
    kAXHelpAttribute, // localized - not helpful
    kAXRoleDescriptionAttribute, // localized - not helpful
]

private let kindSpecificIgnore: [AxKind: Set<String>] = [
    .button: [
        "AXFrame",
        kAXEditedAttribute,
        kAXFocusedAttribute,
        kAXPositionAttribute,
        kAXSizeAttribute,
    ],
    .app: [
        "AXEnhancedUserInterface",
        "AXPreferredLanguage",
        kAXHiddenAttribute,
    ],
]

private let priorityAx: Set<String> = [
    Ax.titleAttr.key,
    Ax.roleAttr.key,
    Ax.subroleAttr.key,
    Ax.identifierAttr.key,
]
