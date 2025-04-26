import AppKit
import Common

func dumpAx(_ ax: AXUIElement, _ kind: AxKind) -> [String: Json] {
    var result: [String: Json] = [:]
    var ignored: [String] = []
    for key: String in ax.attrs.sortedBy({ priorityAx.contains($0) ? 0 : 1 }) {
        var raw: AnyObject?
        AXUIElementCopyAttributeValue(ax, key as CFString, &raw)
        if globalIgnore.contains(key) || kindSpecificIgnore[kind]?.contains(key) == true {
            ignored.append(key)
        } else {
            result[key] = prettyValue(raw as Any?)
        }
    }
    if !ignored.isEmpty {
        result["Aero.AxIgnored"] = .string(ignored.joined(separator: ", "))
    }
    return result
}

enum AxKind: Hashable {
    case button
    case window
    case app
}

private func prettyValue(_ value: Any?) -> Json {
    if let arr = value as? [Any?] {
        return .array(arr.map(prettyValue))
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
            return .dict(dumpAx(ax, .button))
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

private extension AXUIElement {
    var attrs: [String] {
        var rawArray: CFArray?
        AXUIElementCopyAttributeNames(self, &rawArray)
        return rawArray as? [String] ?? []
    }
}

private let globalIgnore: Set<String> = [
    "AXChildren", // too verbose
    "AXChildrenInNavigationOrder", // too verbose
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
